package io_test

import "io"

import "core:os"
import "core:fmt"
import "core:log"
import "core:strings"
import win32 "core:sys/win32"

Lower_Case_Writer :: struct {
    using writer: io.Writer,
    input_writer: ^io.Writer,
}

lower_case_write_proc :: proc(using w: ^Lower_Case_Writer, data: []byte) -> (int, io.Error) {
    wrote := 0;

    for b in data {
        b := b;

        if b >= 0x41 && b <= 0x5A {
            b += 0x20;
        }

        n, err := io.write_byte(w.input_writer, b);
        wrote += n;
        if err != .Ok {
            return wrote, err;
        }
    }

    return wrote, .Ok;
};

make_lower_case_writer :: proc(input_writer: ^io.Writer) -> Lower_Case_Writer {
    lcw := Lower_Case_Writer{};
    lcw.write_proc = cast(type_of(lcw.write_proc)) lower_case_write_proc;
    lcw.input_writer = input_writer;

    return lcw;
}


main :: proc() {
    context.logger = log.create_console_logger();

    Some_Struct :: struct {
        a: u8,
        b: u16,
        c: u32,
    };

    { // very basic writer example
        fw, _ := io.create_file("basic.txt");
        defer io.close_file_writer(&fw);

        io.write_any(&fw, Some_Struct{100, 2000, 20000000});
    }

    { // very basic reader example
        fr, _ := io.open_file_reader("basic.txt");
        defer io.close_file_reader(&fr);

        a, _ := io.read_typeid(&fr, Some_Struct);
        fmt.println(a);
    }

    {
        fw, _ := io.create_file("test.txt");
        defer io.close_file_writer(&fw);

        // Example of a wrapping writer
        lcw := make_lower_case_writer(&fw);

        log_writer := io.Writer {
            proc(writer: ^io.Writer, data: []byte) -> (int, io.Error) {
                fmt.printf("wrote %d bytes\n", len(data));
                return len(data), .Ok;
            }
        };

        w := io.make_multi_writer({&lcw, &log_writer, io.nil_writer()});
        defer io.delete_multi_writer(&w);

        a := Some_Struct{0x10, 0x2000, 0x40000000};
        fmt.printf("wrote: a.a: 0x%02X, a.b: 0x%04X, a.c: 0x%08X\n", expand_to_tuple(a));
        io.write_any(&w, a);

        t := "This is some data";
        io.write(&w, transmute([]u8) t);
        io.write_byte(&w, '\n');
        io.write_string(&w, "This is some more data\n");

        io.write_any(&w, "This is a string\n");
    }

    { // Append some more data
        fw, _ := io.open_file_writer("test.txt");
        defer io.close_file_writer(&fw);

        str := "'Appended string!'\n";
        n, err := io.write_string(&fw, str);
        if err != .Ok || n != len(str) {
            fmt.printf("Failed to write append string. Err %v\n", err);
        }
    }

    // win32.delete_file_a("test.txt");

    { // Reading a file 8 bytes at a time, using File_Reader
        fr, _ := io.open_file_reader("test.txt");
        //fr, _ := io.make_file_reader(os.Handle(0xFFFF_FFFF_FFFF_FFF6)); // win32 stdin
        defer io.close_file_reader(&fr);

        a, _ := io.read_typeid(&fr, Some_Struct);
        fmt.printf("read: a.a: 0x%02X, a.b: 0x%04X, a.c: 0x%08X\n", expand_to_tuple(a));

        data: [8]byte;
        for {
            n, err := io.read(&fr, data[:]);
            if err != .Ok {
                if err == .End_Of_Stream {
                    break;
                } else {
                    fmt.panicf("read err: %v\n", err);
                }
            }

            for i in 0..<len(data) {
                if i < n {
                    c := data[i];

                    switch c {
                    case ' '..'~':
                        // do nothing
                    case:
                        c = '.';
                    }
                    fmt.printf("%c", c);
                } else {
                    fmt.printf(" ");
                }
            }

            fmt.printf("    ");

            for i in 0..<len(data) {
                if i < n {
                    fmt.printf("%2X ", data[i]);
                }
            }

            fmt.println();
        }
    }
}
