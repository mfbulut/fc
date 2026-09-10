package main

import "core:os"
import "core:strings"

import "fc"

SFX :: #config(SFX, "")
SFX_CREATE :: #config(SFX_CREATE, false)

main :: proc() {
	when SFX_CREATE {
		data := #load(#directory + "temp.fc", []u8)
		decompressed := fc.decompress(data)
		_ = os.write_entire_file(SFX, decompressed)
	} else when SFX != "" {
		data := os.read_entire_file(SFX, context.allocator) or_else panic("Failed to read the file")
		compressed := fc.compress(data)
		_ = os.write_entire_file(#directory + "temp.fc", compressed)
		_, _, _, _ = os.process_exec({ command = {"odin", "build", #directory, "-o:speed", "-no-bounds-check", "-define:SFX_CREATE=true", "-define:SFX=" + SFX, "-out:" + SFX + ".exe"} }, context.allocator)
		os.remove(#directory + "temp.fc")
	} else {
		if len(os.args) < 2 {
			panic("Not enough arguments")
		}

		filepath := os.args[1]
		data := os.read_entire_file(filepath, context.allocator) or_else panic("Failed to read the file")

		if os.ext(filepath) == ".fc" {
			decompressed := fc.decompress(data)
			out_path := os.stem(filepath)
			_ = os.write_entire_file(out_path, decompressed)
		} else {
			compressed := fc.compress(data)
			out_path := strings.concatenate({filepath, ".fc"})
			_ = os.write_entire_file(out_path, compressed)
		}
	}
}