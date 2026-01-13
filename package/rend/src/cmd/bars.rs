use clap::Args;
use std::io::{self, BufRead};

#[derive(Args, Debug)]
pub struct BarsArgs {
    /// Minimum value for the scale
    #[arg(long, default_value = "0")]
    pub min: f64,

    /// Maximum value for the scale
    #[arg(long, default_value = "100")]
    pub max: f64,

    /// Number of segments in the bar
    #[arg(long, default_value = "10")]
    pub count: usize,
}

pub fn cmd_bars(args: BarsArgs) -> Result<(), Box<dyn std::error::Error>> {
    let stdin = io::stdin();
    let reader = stdin.lock();

    for line in reader.lines() {
        let line = line?;
        let line = line.trim();
        
        if line.is_empty() {
            continue;
        }

        match line.parse::<f64>() {
            Ok(value) => {
                let bar = render_bar(value, args.min, args.max, args.count);
                println!("{}", bar);
            }
            Err(_) => {
                eprintln!("Error: '{}' is not a valid number", line);
            }
        }
    }

    Ok(())
}

fn render_bar(value: f64, min: f64, max: f64, count: usize) -> String {
    // Calculate step size
    let range = max - min;
    let step_size = if count > 0 {
        range / count as f64
    } else {
        0.0
    };
    
    // Use precision rendering if step size > 1, otherwise use simple rendering
    if step_size > 1.0 {
        render_bar_precision(value, min, max, count, step_size)
    } else {
        render_bar_simple(value, min, max, count)
    }
}

fn render_bar_simple(value: f64, min: f64, max: f64, count: usize) -> String {
    // Clamp value to the range [min, max]
    let clamped_value = value.clamp(min, max);
    
    // Calculate the ratio of the value within the range
    let ratio = if max > min {
        (clamped_value - min) / (max - min)
    } else {
        0.0
    };
    
    // Calculate how many segments should be filled
    // Ensure filled + unfilled always equals count
    let filled = (ratio * count as f64).round() as usize;
    let filled = filled.min(count); // Cap at count
    let unfilled = count - filled;
    
    // Build the bar: |filled|unfilled|
    format!(
        "|{}|{}|",
        "-".repeat(filled),
        "-".repeat(unfilled)
    )
}

fn render_bar_precision(value: f64, min: f64, max: f64, count: usize, step_size: f64) -> String {
    // Clamp value to the range [min, max]
    let clamped_value = value.clamp(min, max);
    
    // Calculate which segment the value falls into
    let value_offset = clamped_value - min;
    let segment_index = (value_offset / step_size).floor() as usize;
    let segment_index = segment_index.min(count - 1);
    
    // Calculate position within the current segment (0.0 to 1.0)
    let segment_start = segment_index as f64 * step_size;
    let position_in_segment = if clamped_value == max && max > min {
        1.0
    } else {
        (value_offset - segment_start) / step_size
    };
    
    // Determine which character to use for the current segment
    let precision_char = if position_in_segment < 0.333 {
        '\\'
    } else if position_in_segment < 0.666 {
        '|'
    } else {
        '/'
    };
    
    // Build the bar with filled segments, precision character, and unfilled segments
    let mut bar = String::from("|");
    for i in 0..count {
        if i < segment_index {
            bar.push('-');
        } else if i == segment_index {
            bar.push(precision_char);
        } else {
            bar.push('-');
        }
    }
    bar.push('|');
    bar
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_render_bar_simple_basic() {
        assert_eq!(render_bar(0.0, 0.0, 10.0, 10), "||----------|");
        assert_eq!(render_bar(5.0, 0.0, 10.0, 10), "|-----|-----|");
        assert_eq!(render_bar(10.0, 0.0, 10.0, 10), "|----------||");
    }

    #[test]
    fn test_render_bar_simple_30_percent() {
        assert_eq!(render_bar(3.0, 0.0, 10.0, 10), "|---|-------|");
    }

    #[test]
    fn test_render_bar_simple_clamping() {
        assert_eq!(render_bar(15.0, 0.0, 10.0, 10), "|----------||");
        assert_eq!(render_bar(-5.0, 0.0, 10.0, 10), "||----------|");
    }

    #[test]
    fn test_render_bar_precision_beginning_third() {
        assert_eq!(render_bar(10.0, 0.0, 100.0, 10), r#"|-\--------|"#);
        assert_eq!(render_bar(11.0, 0.0, 100.0, 10), r#"|-\--------|"#);
    }

    #[test]
    fn test_render_bar_precision_middle_third() {
        assert_eq!(render_bar(15.0, 0.0, 100.0, 10), r#"|-|--------|"#);
        assert_eq!(render_bar(25.0, 0.0, 100.0, 10), r#"|--|-------|"#);
    }

    #[test]
    fn test_render_bar_precision_last_third() {
        assert_eq!(render_bar(19.0, 0.0, 100.0, 10), r#"|-/--------|"#);
        assert_eq!(render_bar(29.0, 0.0, 100.0, 10), r#"|--/-------|"#);
    }

    #[test]
    fn test_render_bar_precision_boundaries() {
        assert_eq!(render_bar(0.0, 0.0, 100.0, 10), r#"|\---------|"#);
        assert_eq!(render_bar(20.0, 0.0, 100.0, 10), r#"|--\-------|"#);
        assert_eq!(render_bar(100.0, 0.0, 100.0, 10), r#"|---------/|"#);
    }

    #[test]
    fn test_render_bar_precision_clamping() {
        assert_eq!(render_bar(150.0, 0.0, 100.0, 10), r#"|---------/|"#);
        assert_eq!(render_bar(-50.0, 0.0, 100.0, 10), r#"|\---------|"#);
    }

    #[test]
    fn test_render_bar_precision_different_step_sizes() {
        assert_eq!(render_bar(0.0, 0.0, 100.0, 5), r#"|\----|"#);
        assert_eq!(render_bar(10.0, 0.0, 100.0, 5), r#"||----|"#);
        assert_eq!(render_bar(18.0, 0.0, 100.0, 5), r#"|/----|"#);
        assert_eq!(render_bar(30.0, 0.0, 100.0, 5), r#"|-|---|"#);
    }

    #[test]
    fn test_render_bar_edge_case_zero_count() {
        assert_eq!(render_bar(50.0, 0.0, 100.0, 0), r#"|||"#);
    }

    #[test]
    fn test_render_bar_edge_case_same_min_max() {
        assert_eq!(render_bar(50.0, 50.0, 50.0, 10), r#"||----------|"#);
    }

    #[test]
    fn test_render_bar_edge_case_negative_range() {
        assert_eq!(render_bar(-25.0, -50.0, 0.0, 10), r#"|-----\----|"#);
    }

    #[test]
    fn test_render_bar_edge_case_fractional_values() {
        assert_eq!(render_bar(3.7, 0.0, 10.0, 10), r#"|----|------|"#);
        assert_eq!(render_bar(15.5, 0.0, 100.0, 10), r#"|-|--------|"#);
    }

    #[test]
    fn test_render_bar_edge_case_single_segment() {
        assert_eq!(render_bar(0.0, 0.0, 10.0, 1), r#"|\|"#);
        assert_eq!(render_bar(5.0, 0.0, 10.0, 1), r#"|||"#);
        assert_eq!(render_bar(10.0, 0.0, 10.0, 1), r#"|/|"#);
    }

    #[test]
    fn test_render_bar_edge_case_large_count() {
        assert_eq!(render_bar(0.5, 0.0, 1.0, 100), r#"|--------------------------------------------------|--------------------------------------------------|"#);
    }
}
