#!/usr/bin/env python3
"""
PNG alpha flattener (pure Python, no external dependencies).

This script reads a PNG, removes transparency by compositing each pixel over
an opaque white background, and writes out an RGB PNG without an alpha channel.

Supported input:
- Bit depth: 8
- Color type: 6 (RGBA)
- Interlace method: 0 (no interlace)

If the input does not have an alpha channel (e.g., color type 2), the script
will simply rewrite the image unchanged or, if --in-place was specified,
leave the file as is.

Limitations:
- Does not process paletted/gray images with tRNS transparency.
- Does not support interlaced PNGs.
"""

from __future__ import annotations

import argparse
import io
import os
import struct
import sys
import zlib


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


class PNGFormatError(Exception):
    """Raised when the PNG format is unsupported or invalid for this tool."""


def _read_chunk(stream: io.BufferedReader) -> tuple[bytes, bytes]:
    """Read a single PNG chunk and return (type, data).

    Raises EOFError when no more chunks are available.
    """
    length_bytes = stream.read(4)
    if not length_bytes:
        raise EOFError
    if len(length_bytes) != 4:
        raise PNGFormatError("Unexpected EOF while reading chunk length")
    (length,) = struct.unpack(">I", length_bytes)
    chunk_type = stream.read(4)
    if len(chunk_type) != 4:
        raise PNGFormatError("Unexpected EOF while reading chunk type")
    data = stream.read(length)
    if len(data) != length:
        raise PNGFormatError("Unexpected EOF while reading chunk data")
    crc_bytes = stream.read(4)
    if len(crc_bytes) != 4:
        raise PNGFormatError("Unexpected EOF while reading chunk CRC")
    # Optionally validate CRC (skip for performance). Uncomment to enforce:
    # expected_crc = zlib.crc32(chunk_type)
    # expected_crc = zlib.crc32(data, expected_crc) & 0xFFFFFFFF
    # (crc,) = struct.unpack(">I", crc_bytes)
    # if crc != expected_crc:
    #     raise PNGFormatError("CRC mismatch for chunk %r" % chunk_type)
    return chunk_type, data


def _write_chunk(stream: io.BufferedWriter, chunk_type: bytes, data: bytes) -> None:
    stream.write(struct.pack(">I", len(data)))
    stream.write(chunk_type)
    stream.write(data)
    crc = zlib.crc32(chunk_type)
    crc = zlib.crc32(data, crc) & 0xFFFFFFFF
    stream.write(struct.pack(">I", crc))


def _paeth_predictor(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def _unfilter_scanlines(raw: bytes, height: int, scanline_length: int, bytes_per_pixel: int) -> bytearray:
    row_size = scanline_length
    expected_size = height * (1 + row_size)
    if len(raw) != expected_size:
        # Some encoders may add zlib flush or extra bytes; try to handle if longer
        if len(raw) < expected_size:
            raise PNGFormatError("Decompressed IDAT size unexpected: got %d, expected %d" % (len(raw), expected_size))
        raw = raw[:expected_size]

    recon = bytearray(height * row_size)
    prev_row = bytearray(row_size)
    offset = 0

    for y in range(height):
        filter_type = raw[offset]
        offset += 1
        curr = bytearray(raw[offset : offset + row_size])
        offset += row_size

        if filter_type == 0:  # None
            pass
        elif filter_type == 1:  # Sub
            for i in range(row_size):
                left = curr[i - bytes_per_pixel] if i >= bytes_per_pixel else 0
                curr[i] = (curr[i] + left) & 0xFF
        elif filter_type == 2:  # Up
            for i in range(row_size):
                up = prev_row[i]
                curr[i] = (curr[i] + up) & 0xFF
        elif filter_type == 3:  # Average
            for i in range(row_size):
                left = curr[i - bytes_per_pixel] if i >= bytes_per_pixel else 0
                up = prev_row[i]
                curr[i] = (curr[i] + ((left + up) // 2)) & 0xFF
        elif filter_type == 4:  # Paeth
            for i in range(row_size):
                left = curr[i - bytes_per_pixel] if i >= bytes_per_pixel else 0
                up = prev_row[i]
                up_left = prev_row[i - bytes_per_pixel] if i >= bytes_per_pixel else 0
                curr[i] = (curr[i] + _paeth_predictor(left, up, up_left)) & 0xFF
        else:
            raise PNGFormatError(f"Unsupported PNG filter type: {filter_type}")

        start = y * row_size
        recon[start : start + row_size] = curr
        prev_row = curr

    return recon


def _flatten_rgba_over_white(rgba_bytes: bytearray) -> bytes:
    if len(rgba_bytes) % 4 != 0:
        raise PNGFormatError("RGBA buffer length is not divisible by 4")
    out = bytearray((len(rgba_bytes) // 4) * 3)
    j = 0
    for i in range(0, len(rgba_bytes), 4):
        r = rgba_bytes[i]
        g = rgba_bytes[i + 1]
        b = rgba_bytes[i + 2]
        a = rgba_bytes[i + 3]
        inv_a = 255 - a
        out[j] = (r * a + 255 * inv_a) // 255
        out[j + 1] = (g * a + 255 * inv_a) // 255
        out[j + 2] = (b * a + 255 * inv_a) // 255
        j += 3
    return bytes(out)


def flatten_png_alpha_to_white(src_path: str, dst_path: str | None, overwrite: bool) -> str:
    with open(src_path, 'rb') as f:
        sig = f.read(8)
        if sig != PNG_SIGNATURE:
            raise PNGFormatError("Not a PNG file")

        # Parse IHDR
        chunk_type, data = _read_chunk(f)
        if chunk_type != b'IHDR':
            raise PNGFormatError("First chunk is not IHDR")
        if len(data) != 13:
            raise PNGFormatError("IHDR chunk has invalid length")
        width, height, bit_depth, color_type, compression, filter_method, interlace = struct.unpack(
            ">IIBBBBB", data
        )
        if bit_depth != 8:
            raise PNGFormatError("Only 8-bit PNGs are supported")
        if interlace != 0:
            raise PNGFormatError("Interlaced PNGs are not supported")
        if compression != 0 or filter_method != 0:
            raise PNGFormatError("Unsupported PNG compression or filter method")

        # Collect PLTE/tRNS, IDAT and pass-through ancillary chunks for potential reuse.
        idat_parts: list[bytes] = []
        ancillary_chunks: list[tuple[bytes, bytes]] = []
        plte: bytes | None = None
        trns: bytes | None = None

        while True:
            try:
                chunk_type, data = _read_chunk(f)
            except EOFError:
                break

            if chunk_type == b'IDAT':
                idat_parts.append(data)
            elif chunk_type == b'PLTE':
                plte = data
            elif chunk_type == b'tRNS':
                trns = data
            elif chunk_type == b'IEND':
                break
            else:
                ancillary_chunks.append((chunk_type, data))

        if not idat_parts:
            raise PNGFormatError("No IDAT chunks found")

        idat_data = b"".join(idat_parts)
        try:
            decompressed = zlib.decompress(idat_data)
        except zlib.error as exc:
            raise PNGFormatError(f"Failed to decompress IDAT: {exc}") from exc

        # Determine layout
        if color_type == 6:  # RGBA
            channels = 4
            bpp = 4  # 8-bit only supported
            scanline_len = width * bpp
        elif color_type == 2:  # RGB
            channels = 3
            bpp = 3  # 8-bit only supported
            scanline_len = width * bpp
        elif color_type == 3:  # Indexed-color
            channels = 1
            # Bytes-per-pixel for filtering = ceil(bits_per_pixel/8) which is 1 for 1/2/4/8
            bpp = max(1, (bit_depth + 7) // 8)
            # Scanline length in bytes = ceil(width * bit_depth / 8)
            scanline_len = (width * bit_depth + 7) // 8
        else:
            raise PNGFormatError(f"Unsupported color type: {color_type}")

        recon = _unfilter_scanlines(
            raw=decompressed,
            height=height,
            scanline_length=scanline_len,
            bytes_per_pixel=bpp,
        )

        if color_type == 6:
            rgb_bytes = _flatten_rgba_over_white(recon)
        elif color_type == 2:
            # Already opaque RGB; write as-is
            rgb_bytes = bytes(recon)
        else:  # color_type == 3
            if plte is None:
                raise PNGFormatError("PLTE chunk missing for indexed-color PNG")
            if len(plte) % 3 != 0:
                raise PNGFormatError("PLTE chunk length is not a multiple of 3")
            num_palette = len(plte) // 3
            palette = [(plte[i], plte[i + 1], plte[i + 2]) for i in range(0, len(plte), 3)]
            # Build alpha table
            alpha = [255] * num_palette
            if trns is not None:
                for i in range(min(num_palette, len(trns))):
                    alpha[i] = trns[i]

            # Expand indices to RGB with white compositing
            rgb = bytearray(width * height * 3)
            out_off = 0
            row_len = scanline_len

            def get_index_from_row(row: bytes, x: int) -> int:
                if bit_depth == 8:
                    return row[x]
                elif bit_depth == 4:
                    byte = row[x // 2]
                    return (byte >> 4) & 0x0F if (x % 2) == 0 else (byte & 0x0F)
                elif bit_depth == 2:
                    byte = row[x // 4]
                    shift = 6 - 2 * (x % 4)
                    return (byte >> shift) & 0x03
                elif bit_depth == 1:
                    byte = row[x // 8]
                    shift = 7 - (x % 8)
                    return (byte >> shift) & 0x01
                else:
                    raise PNGFormatError(f"Unsupported bit depth for indexed color: {bit_depth}")

            for y in range(height):
                row = recon[y * row_len : (y + 1) * row_len]
                for x in range(width):
                    idx = get_index_from_row(row, x)
                    if idx >= num_palette:
                        # Spec says missing entries treated as black, but we'll clamp
                        r = g = b_ = 0
                        a = 255
                    else:
                        r, g, b_ = palette[idx]
                        a = alpha[idx]
                    inv_a = 255 - a
                    rgb[out_off] = (r * a + 255 * inv_a) // 255
                    rgb[out_off + 1] = (g * a + 255 * inv_a) // 255
                    rgb[out_off + 2] = (b_ * a + 255 * inv_a) // 255
                    out_off += 3

            rgb_bytes = bytes(rgb)

        # Re-encode as RGB (color type 2), filter type 0 for all rows
        row_size_rgb = width * 3
        out_raw = bytearray(height * (1 + row_size_rgb))
        off = 0
        for y in range(height):
            out_raw[off] = 0  # filter type 0
            off += 1
            start = y * row_size_rgb
            out_raw[off : off + row_size_rgb] = rgb_bytes[start : start + row_size_rgb]
            off += row_size_rgb

        compressed = zlib.compress(bytes(out_raw), level=9)

        # Build new PNG: signature, IHDR (RGB), optional sRGB if present, IDAT, IEND
        output_path = dst_path or (src_path if overwrite else src_path + ".flattened.png")
        with open(output_path, 'wb') as out:
            out.write(PNG_SIGNATURE)
            new_ihdr = struct.pack(
                ">IIBBBBB",
                width,
                height,
                8,  # bit depth
                2,  # color type: truecolor (RGB)
                0,  # compression method
                0,  # filter method
                0,  # interlace method
            )
            _write_chunk(out, b'IHDR', new_ihdr)

            # Optionally pass through sRGB/gAMA/chrm if present; skip others safely.
            for ctype, cdata in ancillary_chunks:
                if ctype in {b'sRGB', b'gAMA', b'cHRM'}:
                    _write_chunk(out, ctype, cdata)

            _write_chunk(out, b'IDAT', compressed)
            _write_chunk(out, b'IEND', b'')

        return output_path


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Flatten PNG alpha over white background")
    parser.add_argument("input", help="Path to input PNG")
    parser.add_argument("--output", "-o", help="Path to output PNG (default: overwrite or input.flattened.png)")
    parser.add_argument("--in-place", action="store_true", help="Overwrite the input file in place")
    args = parser.parse_args(argv)

    if not os.path.isfile(args.input):
        print(f"Input file not found: {args.input}", file=sys.stderr)
        return 2

    try:
        out_path = flatten_png_alpha_to_white(
            src_path=args.input,
            dst_path=args.output,
            overwrite=args.in_place and args.output is None,
        )
    except PNGFormatError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    print(out_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

