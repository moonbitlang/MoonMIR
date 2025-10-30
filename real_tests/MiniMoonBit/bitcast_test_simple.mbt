fn analyze_float_bits() -> Unit {
  // Analyze the bit pattern of a float
  let values: Array[Float] = [1.0F, 2.0F, 3.0F, -1.0F, 0.5F];
  
  for i = 0; i < values.length(); i = i + 1 {
    let f: Float = values[i];
    let bits: Int = f.reinterpret_as_int();
    println(f);
    println(bits);
  }
}

fn analyze_double_bits() -> Unit {
  // Analyze the bit pattern of a double
  let values: Array[Double] = [1.0, 2.0, 3.0, -1.0, 0.5];
  
  for i = 0; i < values.length(); i = i + 1 {
    let d: Double = values[i];
    let bits: Int64 = d.reinterpret_as_int64();
    println(d);
    println(bits);
  }
}

fn main {
  analyze_float_bits();
  analyze_double_bits();
}

