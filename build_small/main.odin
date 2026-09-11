package main

import "base:runtime"
import "../fc"

foreign import kernel32 "system:Kernel32.lib"
foreign import shell32  "system:Shell32.lib"

HANDLE :: rawptr
INVALID_HANDLE_VALUE :: HANDLE(~uintptr(0))

GENERIC_READ          :: 0x80000000
GENERIC_WRITE         :: 0x40000000
FILE_SHARE_READ       :: 1
OPEN_EXISTING         :: 3
CREATE_ALWAYS         :: 2
FILE_ATTRIBUTE_NORMAL :: 128

@(default_calling_convention="system")
foreign kernel32 {
	CreateFileA         :: proc(lpFileName: cstring, dwDesiredAccess, dwShareMode: u32, lpSecurityAttributes: rawptr, dwCreationDisposition, dwFlagsAndAttributes: u32, hTemplateFile: HANDLE) -> HANDLE ---
	ReadFile            :: proc(hFile: HANDLE, lpBuffer: rawptr, nNumberOfBytesToRead: u32, lpNumberOfBytesRead: ^u32, lpOverlapped: rawptr) -> b32 ---
	WriteFile           :: proc(hFile: HANDLE, lpBuffer: rawptr, nNumberOfBytesToWrite: u32, lpNumberOfBytesWritten: ^u32, lpOverlapped: rawptr) -> b32 ---
	CloseHandle         :: proc(hObject: HANDLE) -> b32 ---
	GetFileSizeEx       :: proc(hFile: HANDLE, lpFileSize: ^i64) -> b32 ---
	GetCommandLineW     :: proc() -> [^]u16 ---
	WideCharToMultiByte :: proc(CodePage, dwFlags: u32, lpWideCharStr: [^]u16, cchWideChar: i32, lpMultiByteStr: [^]u8, cbMultiByte: i32, lpDefaultChar, lpUsedDefaultChar: rawptr) -> i32 ---
}

@(default_calling_convention="system")
foreign shell32 {
	CommandLineToArgvW  :: proc(lpCmdLine: [^]u16, pNumArgs: ^i32) -> [^][^]u16 ---
}

read_entire_file :: proc(filename: string) -> ([]u8, bool) {
	buf_name: [512]u8
	if len(filename) >= len(buf_name) do return nil, false
	copy(buf_name[:], filename)
	buf_name[len(filename)] = 0

	h := CreateFileA(cstring(&buf_name[0]), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nil)
	if h == INVALID_HANDLE_VALUE do return nil, false
	defer CloseHandle(h)

	size: i64
	if !GetFileSizeEx(h, &size) || size <= 0 do return nil, false

	data := make([]u8, int(size))
	read_bytes: u32
	if !ReadFile(h, raw_data(data), u32(size), &read_bytes, nil) {
		delete(data)
		return nil, false
	}
	return data, true
}

write_entire_file :: proc(filename: string, data: []u8) -> bool {
	buf_name: [512]u8
	if len(filename) >= len(buf_name) do return false
	copy(buf_name[:], filename)
	buf_name[len(filename)] = 0

	h := CreateFileA(cstring(&buf_name[0]), GENERIC_WRITE, 0, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nil)
	if h == INVALID_HANDLE_VALUE do return false
	defer CloseHandle(h)

	written: u32
	return bool(WriteFile(h, raw_data(data), u32(len(data)), &written, nil))
}

concat_fc :: proc(path: string) -> string {
	buf := make([]u8, len(path) + 3)
	copy(buf, path)
	copy(buf[len(path):], ".fc")
	return string(buf)
}

has_fc_ext :: proc(path: string) -> bool {
	return len(path) >= 3 && path[len(path)-3:] == ".fc"
}

@(link_name="mainCRTStartup", linkage="strong", require)
mainCRTStartup :: proc "system" () -> i32 {
	context = {}
	context.allocator = runtime.default_allocator()

	num_args: i32
	argv_w := CommandLineToArgvW(GetCommandLineW(), &num_args)
	if argv_w == nil || num_args < 2 {
		return 1
	}

	wstr := argv_w[1]
	len_needed := WideCharToMultiByte(65001, 0, wstr, -1, nil, 0, nil, nil)
	arg_buf := make([]u8, int(len_needed))

	WideCharToMultiByte(65001, 0, wstr, -1, raw_data(arg_buf), len_needed, nil, nil)
	filepath := string(arg_buf[:len_needed - 1])

	data, ok := read_entire_file(filepath)
	if !ok do return 1

	if has_fc_ext(filepath) {
		decompressed := fc.decompress(data)
		out_path := filepath[:len(filepath)-3]
		_ = write_entire_file(out_path, decompressed)
	} else {
		compressed := fc.compress(data)
		out_path := concat_fc(filepath)
		_ = write_entire_file(out_path, compressed)
	}

	return 0
}
