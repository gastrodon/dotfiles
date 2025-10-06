use std::env::args;
use std::fs::{metadata, read_to_string, write};
use std::process::exit;

fn read_u32_from_file(path: &str) -> u32 {
    read_to_string(path)
        .expect("k")
        .trim()
        .parse()
        .expect("Invalid number")
}

fn read_bright(max_path: &str, brightness_path: &str) {
    let max = read_u32_from_file(max_path);
    let current = read_u32_from_file(brightness_path);
    let percentage = (current * 100) / max;
    println!("{}", percentage);
}

fn write_bright(value_str: &str, max_path: &str, brightness_path: &str) {
    let value: u32 = value_str.parse().expect("Value must be an integer");
    if value < 1 || value > 100 {
        eprintln!("Error: Value must be an integer between 1 and 100");
        exit(1);
    }
    let max = read_u32_from_file(max_path);
    let scaled = (value * max) / 100;
    write(brightness_path, scaled.to_string()).expect("Failed to set brightness");
}

fn main() {
    let args: Vec<String> = args().collect();
    let backlight_path = "/sys/class/backlight/intel_backlight";
    let max_path = format!("{}/max_brightness", backlight_path);
    let brightness_path = format!("{}/brightness", backlight_path);

    if args.len() == 1 {
        read_bright(&max_path, &brightness_path);
    } else {
        write_bright(&args[1], &max_path, &brightness_path);
    }
}
