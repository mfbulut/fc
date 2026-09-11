package fc

import "core:slice"
import "core:encoding/endian"

State :: struct {
	C0: [256]u16,
	C1: [256][256]u16,
	C2: [512][17]u16,
}

update0 :: #force_inline proc "contextless" (p: ^u16, x: u32) {
	p^ = p^ - (p^ >> x)
}

update1 :: #force_inline proc "contextless" (p: ^u16, x: u32) {
	p^ = p^ + ((p^ ~ 0xFFFF) >> x)
}

entropy_begin :: proc() -> ^State {
	s := new(State)

	slice.fill(s.C0[:], 1 << 15)

	for &row in s.C1 {
		slice.fill(row[:], 1 << 15)
	}

	for i in 0 ..< 2 {
		for j in 0 ..< 256 {
			for k in 0 ..< 17 {
				s.C2[2*j + i][k] = u16((k << 12) - (1 if k == 16 else 0))
			}
		}
	}

	return s
}

entropy_encode :: proc(input: []u8, output: []u8) -> (ent_length: int) {
	s := entropy_begin()
	defer free(s)

	high: u32 = 0xFFFFFFFF
	low: u32 = 0
	c1: int = 0
	c2: int = 0
	run: int = 0

	for b in input {
		c := b
		if c1 == c2 {
			run += 1
		} else {
			run = 0
		}

		f := 1 if run > 2 else 0
		ctx := 1

		for ctx < 256 {
			p0 := int(s.C0[ctx])
			p1 := int(s.C1[c1][ctx])
			p2 := int(s.C1[c2][ctx])
			p := ((p0 + p1) * 7 + p2 + p2) >> 4

			j := p >> 12
			x1 := int(s.C2[2*ctx + f][j])
			x2 := int(s.C2[2*ctx + f][j + 1])
			ssep := x1 + (((x2 - x1) * (p & 4095)) >> 12)
			split := u64(ssep * 3 + p)

			if (c & 128) != 0 {
				high = low + u32((u64(high - low) * split) >> 18)

				for (low ~ high) < (1 << 24) {
					output[ent_length] = u8(low >> 24)
					ent_length += 1
					low <<= 8
					high = (high << 8) + 0xFF
				}

				update1(&s.C0[ctx], 2)
				update1(&s.C1[c1][ctx], 4)
				update1(&s.C2[2*ctx + f][j], 6)
				update1(&s.C2[2*ctx + f][j + 1], 6)
				ctx = ctx + ctx + 1
			} else {
				low += u32((u64(high - low) * split) >> 18) + 1

				for (low ~ high) < (1 << 24) {
					output[ent_length] = u8(low >> 24)
					ent_length += 1
					low <<= 8
					high = (high << 8) + 0xFF
				}

				update0(&s.C0[ctx], 2)
				update0(&s.C1[c1][ctx], 4)
				update0(&s.C2[2*ctx + f][j], 6)
				update0(&s.C2[2*ctx + f][j + 1], 6)
				ctx = ctx + ctx
			}

			c <<= 1
		}

		c2 = c1
		c1 = ctx & 255
	}

	endian.unchecked_put_u32be(output[ent_length:], low)
	ent_length += 4

	return ent_length
}

entropy_decode :: proc(input: []u8, output: []u8) {
	s := entropy_begin()
	defer free(s)

	in_len := len(input)
	in_index := 4

	c1: int = 0
	c2: int = 0
	run: int = 0
	low: u32 = 0
	high: u32 = 0xFFFFFFFF
	code: u32 = endian.unchecked_get_u32be(input[:4])

	for i in 0 ..< len(output) {
		if c1 == c2 {
			run += 1
		} else {
			run = 0
		}

		f := 1 if run > 2 else 0
		ctx := 1

		for ctx < 256 {
			p0 := int(s.C0[ctx])
			p1 := int(s.C1[c1][ctx])
			p2 := int(s.C1[c2][ctx])
			p := ((p0 + p1) * 7 + p2 + p2) >> 4

			j := p >> 12
			x1 := int(s.C2[2*ctx + f][j])
			x2 := int(s.C2[2*ctx + f][j + 1])
			ssep := x1 + (((x2 - x1) * (p & 4095)) >> 12)
			split := u64(ssep * 3 + p)

			mid := low + u32((u64(high - low) * split) >> 18)
			bit := code <= mid

			if bit {
				high = mid
			} else {
				low = mid + 1
			}

			for (low ~ high) < (1 << 24) {
				low <<= 8
				high = (high << 8) + 255
				code <<= 8
				if in_index < in_len {
					code += u32(input[in_index])
					in_index += 1
				}
			}

			if bit {
				update1(&s.C0[ctx], 2)
				update1(&s.C1[c1][ctx], 4)
				update1(&s.C2[2*ctx + f][j], 6)
				update1(&s.C2[2*ctx + f][j + 1], 6)
				ctx = ctx + ctx + 1
			} else {
				update0(&s.C0[ctx], 2)
				update0(&s.C1[c1][ctx], 4)
				update0(&s.C2[2*ctx + f][j], 6)
				update0(&s.C2[2*ctx + f][j + 1], 6)
				ctx = ctx + ctx
			}
		}

		c2 = c1
		c1 = ctx & 255
		output[i] = u8(c1)
	}
}

compress :: proc(input: []u8) -> []u8 {
	orig_size := u32(len(input))

	out_buf := make([]u8, orig_size + orig_size / 32 + 256)
	bwt_buf := make([]u8, orig_size)
	defer delete(bwt_buf)

	bwt_index := bwt_encode(input, bwt_buf)
	ent_length := entropy_encode(bwt_buf, out_buf[8:])
	copy(out_buf, slice.to_bytes([]u32{orig_size, bwt_index}))

	return out_buf[:8 + ent_length]
}

decompress :: proc(input: []u8) -> []u8 {
	if len(input) < 12 do return nil

	orig_size := slice.to_type(input[0:4], u32)
	bwt_index := slice.to_type(input[4:8], u32)

	out_buf := make([]u8, orig_size)
	ent_buf := make([]u8, orig_size + 256)
	defer delete(ent_buf)

	entropy_decode(input[8:], ent_buf[:orig_size])
	bwt_decode(ent_buf[:orig_size], out_buf, bwt_index)

	return out_buf
}
