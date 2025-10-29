struct Matrix {
  data : Array[Array[Double]];
  rows : Int;
  cols : Int;
}

fn alloc_mat(rows : Int, cols : Int) -> Matrix {
  let data = Array::make(rows, Array::make(cols, 0.0));
  let mut i = 0;
  while i < rows {
    data[i] = Array::make(cols, 0.0);
    i = i + 1;
  }
  Matrix::{ data: data, rows: rows, cols: cols }
}

fn mat_set(m : Matrix, i : Int, j : Int, value : Double) -> Unit {
  m.data[i][j] = value;
}

fn main {
  let n = 2;
  let a = alloc_mat(n, n);
  let v = alloc_mat(n, n);
  
  // Initialize a
  let mut i = 0;
  while i < n {
    let mut j = 0;
    while j < n {
      mat_set(a, i, j, float_of_int(i * n + j));
      j = j + 1;
    }
    i = i + 1;
  }
  
  // Initialize v
  let mut i = 0;
  while i < n {
    let mut j = 0;
    while j < n {
      mat_set(v, i, j, if i == j { 1.0 } else { 0.0 });
      j = j + 1;
    }
    i = i + 1;
  }
  
  print_int(42);
}
