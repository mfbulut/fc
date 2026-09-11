package fc

import "core:slice"

is_s_get :: #force_inline proc "contextless" (b: []u64, i: int) -> bool {
	return (b[i >> 6] & (1 << u64(i & 63))) != 0
}

is_s_set :: #force_inline proc "contextless" (b: []u64, i: int) {
	b[i >> 6] |= (1 << u64(i & 63))
}

get_buckets :: #force_inline proc "contextless" (counts: []i32, bkt: []i32, k: int, end: bool) {
	sum: i32 = 0
	if end {
		for i in 0..<k {
			sum += counts[i]
			bkt[i] = sum
		}
	} else {
		for i in 0..<k {
			bkt[i] = sum
			sum += counts[i]
		}
	}
}

induce_sort :: proc(s: []$T, sa: []i32, is_s: []u64, n: int, k: int, counts: []i32, bkt: []i32) {
	get_buckets(counts, bkt, k, false)
	for i in 0..<n {
		j := sa[i] - 1
		if j >= 0 && !is_s_get(is_s, int(j)) {
			c := int(s[j])
			sa[bkt[c]] = j
			bkt[c] += 1
		}
	}

	get_buckets(counts, bkt, k, true)
	for i := n - 1; i >= 0; i -= 1 {
		j := sa[i] - 1
		if j >= 0 && is_s_get(is_s, int(j)) {
			c := int(s[j])
			bkt[c] -= 1
			sa[bkt[c]] = j
		}
	}
}

sais :: proc(s: []$T, sa: []i32, n: int, k: int) {
	words := (n + 63) / 64
	is_s := make([]u64, words)
	defer delete(is_s)

	is_s_set(is_s, n - 1)
	for i := n - 2; i >= 0; i -= 1 {
		if s[i] < s[i + 1] || (s[i] == s[i + 1] && is_s_get(is_s, i + 1)) {
			is_s_set(is_s, i)
		}
	}

	counts := make([]i32, k)
	defer delete(counts)
	for i in 0..<n do counts[s[i]] += 1

	bkt := make([]i32, k)
	defer delete(bkt)

	slice.fill(sa, -1)
	get_buckets(counts, bkt, k, true)
	for i in 1..<n {
		if is_s_get(is_s, i) && !is_s_get(is_s, i - 1) {
			c := int(s[i])
			bkt[c] -= 1
			sa[bkt[c]] = i32(i)
		}
	}

	induce_sort(s, sa, is_s, n, k, counts, bkt)

	n1 := 0
	for i in 0..<n {
		if sa[i] > 0 && is_s_get(is_s, int(sa[i])) && !is_s_get(is_s, int(sa[i] - 1)) {
			sa[n1] = sa[i]
			n1 += 1
		}
	}
	for i in n1..<n do sa[i] = -1

	name: i32 = 0
	prev: i32 = -1
	for i in 0..<n1 {
		pos := sa[i]
		diff := false
		if prev == -1 {
			diff = true
		} else {
			for d: i32 = 0; ; d += 1 {
				p1 := pos + d
				p2 := prev + d
				if p1 >= i32(n) || p2 >= i32(n) || s[p1] != s[p2] || is_s_get(is_s, int(p1)) != is_s_get(is_s, int(p2)) {
					diff = true
					break
				}
				if d > 0 && ((is_s_get(is_s, int(p1)) && !is_s_get(is_s, int(p1 - 1))) || (is_s_get(is_s, int(p2)) && !is_s_get(is_s, int(p2 - 1)))) {
					break
				}
			}
		}

		if diff {
			name += 1
			prev = pos
		}

		pos = pos >> 1 if (pos & 1) == 0 else (pos - 1) >> 1
		sa[n1 + int(pos)] = name - 1
	}

	s1 := make([]i32, n1)
	defer delete(s1)
	j := 0
	for i in n1..<n {
		if sa[i] >= 0 {
			s1[j] = sa[i]
			j += 1
		}
	}

	sa1 := make([]i32, n1)
	defer delete(sa1)
	if int(name) < n1 {
		sais(s1, sa1, n1, int(name))
	} else {
		for i in 0..<n1 do sa1[s1[i]] = i32(i)
	}

	get_buckets(counts, bkt, k, true)
	j = 0
	for i in 1..<n {
		if is_s_get(is_s, i) && !is_s_get(is_s, i - 1) {
			s1[j] = i32(i)
			j += 1
		}
	}
	for i in 0..<n1 do sa1[i] = s1[sa1[i]]

	slice.fill(sa, -1)
	for i := n1 - 1; i >= 0; i -= 1 {
		pos := sa1[i]
		c := int(s[pos])
		bkt[c] -= 1
		sa[bkt[c]] = pos
	}

	induce_sort(s, sa, is_s, n, k, counts, bkt)
}

bwt_encode :: proc(input: []u8, output: []u8) -> u32 {
	n := len(input)

	s := make([]u16, n + 1)
	defer delete(s)
	for i in 0..<n do s[i] = u16(input[i]) + 1
	s[n] = 0

	sa := make([]i32, n + 1)
	defer delete(sa)
	sais(s, sa, n + 1, 257)

	p: u32 = 0
	for k in 1..=n {
		if sa[k] == 0 {
			p = u32(k)
			break
		}
	}

	output[0] = input[n - 1]
	for k in 1..<int(p) {
		output[k] = input[sa[k] - 1]
	}
	for k in int(p)..<n {
		output[k] = input[sa[k + 1] - 1]
	}

	return p
}

bwt_decode :: proc(bwt: []u8, output: []u8, p_idx: u32) {
	n := len(bwt)
	p := int(p_idx)

	count: [256]u32
	for c in bwt do count[c] += 1

	cumul: [256]u32
	sum: u32 = 1
	for count_val, i in count {
		cumul[i] = sum
		sum += count_val
	}

	lf := make([]u32, n + 1)
	defer delete(lf)

	for r in 0..<p {
		c := bwt[r]
		lf[r] = cumul[c]
		cumul[c] += 1
	}
	lf[p] = 0
	for r in (p + 1)..=n {
		c := bwt[r - 1]
		lf[r] = cumul[c]
		cumul[c] += 1
	}

	curr := u32(0)
	for i := n - 1; i >= 0; i -= 1 {
		c := bwt[curr] if curr < u32(p) else bwt[curr - 1]
		output[i] = c
		curr = lf[curr]
	}
}