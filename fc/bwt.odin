package fc

import "core:slice"

// Linear-Time Suffix Array Induced Sorting (SA-IS)
sais :: proc(s: []int, sa: []int, n: int, k: int) {
	is_s := make([]bool, n)
	defer delete(is_s)

	is_s[n - 1] = true
	for i := n - 2; i >= 0; i -= 1 {
		is_s[i] = s[i] < s[i + 1] || (s[i] == s[i + 1] && is_s[i + 1])
	}

	bkt := make([]int, k)
	defer delete(bkt)

	get_buckets :: proc(s: []int, bkt: []int, n: int, k: int, end: bool) {
		slice.zero(bkt)
		for i in 0..<n do bkt[s[i]] += 1
		sum := 0
		for i in 0..<k {
			sum += bkt[i]
			bkt[i] = sum if end else (sum - bkt[i])
		}
	}

	induce_sort :: proc(s: []int, sa: []int, is_s: []bool, n: int, k: int, bkt: []int) {
		get_buckets(s, bkt, n, k, false)
		for i in 0..<n {
			j := sa[i] - 1
			if j >= 0 && !is_s[j] {
				sa[bkt[s[j]]] = j
				bkt[s[j]] += 1
			}
		}

		get_buckets(s, bkt, n, k, true)
		for i := n - 1; i >= 0; i -= 1 {
			j := sa[i] - 1
			if j >= 0 && is_s[j] {
				bkt[s[j]] -= 1
				sa[bkt[s[j]]] = j
			}
		}
	}

	slice.fill(sa, -1)
	get_buckets(s, bkt, n, k, true)
	for i in 1..<n {
		if is_s[i] && !is_s[i - 1] {
			bkt[s[i]] -= 1
			sa[bkt[s[i]]] = i
		}
	}

	induce_sort(s, sa, is_s, n, k, bkt)

	n1 := 0
	for i in 0..<n {
		if sa[i] > 0 && is_s[sa[i]] && !is_s[sa[i] - 1] {
			sa[n1] = sa[i]
			n1 += 1
		}
	}
	for i in n1..<n do sa[i] = -1

	name := 0
	prev := -1
	for i in 0..<n1 {
		pos := sa[i]
		diff := false
		if prev == -1 {
			diff = true
		} else {
			for d := 0; ; d += 1 {
				p1 := pos + d
				p2 := prev + d
				if p1 >= n || p2 >= n || s[p1] != s[p2] || is_s[p1] != is_s[p2] {
					diff = true
					break
				}
				if d > 0 && (is_s[p1] && !is_s[p1 - 1] || is_s[p2] && !is_s[p2 - 1]) {
					break
				}
			}
		}

		if diff {
			name += 1
			prev = pos
		}

		pos = pos >> 1 if (pos & 1) == 0 else (pos - 1) >> 1
		sa[n1 + pos] = name - 1
	}

	s1 := make([]int, n1)
	defer delete(s1)
	j := 0
	for i in n1..<n {
		if sa[i] >= 0 {
			s1[j] = sa[i]
			j += 1
		}
	}

	sa1 := make([]int, n1)
	defer delete(sa1)
	if name < n1 {
		sais(s1, sa1, n1, name)
	} else {
		for i in 0..<n1 do sa1[s1[i]] = i
	}

	get_buckets(s, bkt, n, k, true)
	j = 0
	for i in 1..<n {
		if is_s[i] && !is_s[i - 1] {
			s1[j] = i
			j += 1
		}
	}
	for i in 0..<n1 do sa1[i] = s1[sa1[i]]

	slice.fill(sa, -1)
	for i := n1 - 1; i >= 0; i -= 1 {
		pos := sa1[i]
		bkt[s[pos]] -= 1
		sa[bkt[s[pos]]] = pos
	}

	induce_sort(s, sa, is_s, n, k, bkt)
}

bwt_encode :: proc(input: []u8, output: []u8) -> u32 {
	n := len(input)

	s := make([]int, n + 1)
	defer delete(s)
	for i in 0..<n do s[i] = int(input[i]) + 1
	s[n] = 0

	sa := make([]int, n + 1)
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
