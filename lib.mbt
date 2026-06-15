struct GameState {
  rows: Int
  cols: Int
  board: Array[Int]
  selected: Option[(Int, Int)]
  matchedPairs: Int
  totalPairs: Int
}

struct Point {
  x: Int
  y: Int
} derive(Debug, Eq)

struct PathResult {
  found: Bool
  points: Array[Point]
}

fn point_new(x: Int, y: Int) -> Point {
  { x, y }
}

fn get_idx(_rows: Int, cols: Int, r: Int, c: Int) -> Int {
  r * cols + c
}

fn get_at(board: Array[Int], rows: Int, cols: Int, r: Int, c: Int) -> Int {
  if r >= 0 && r < rows && c >= 0 && c < cols {
    board[get_idx(rows, cols, r, c)]
  } else {
    0
  }
}

fn set_at(board: Array[Int], rows: Int, cols: Int, r: Int, c: Int, v: Int) -> Unit {
  if r >= 0 && r < rows && c >= 0 && c < cols {
    board[get_idx(rows, cols, r, c)] = v
  }
}

fn is_empty(board: Array[Int], rows: Int, cols: Int, r: Int, c: Int) -> Bool {
  get_at(board, rows, cols, r, c) == 0
}

fn math_random() -> Double = "Math" "random"
fn math_floor(d: Double) -> Double = "Math" "floor"

fn random_int(n: Int) -> Int {
  if n <= 0 {
    0
  } else {
    let d = math_random() * (n.to_double())
    math_floor(d).to_int()
  }
}

fn shuffle(arr: Array[Int]) -> Unit {
  let n = arr.length()
  let mut i = n - 1
  while i > 0 {
    let j = random_int(i + 1)
    let tmp = arr[i]
    arr[i] = arr[j]
    arr[j] = tmp
    i = i - 1
  }
}

pub fn init_game(rows: Int, cols: Int, tile_types: Int) -> GameState {
  let total_cells = rows * cols
  let pairs = total_cells / 2
  let tiles: Array[Int] = []
  let mut i = 0
  while i < pairs {
    let tile_type = (i % tile_types) + 1
    tiles.push(tile_type)
    tiles.push(tile_type)
    i = i + 1
  }
  shuffle(tiles)
  let board: Array[Int] = []
  let mut j = 0
  while j < total_cells {
    board.push(tiles[j])
    j = j + 1
  }
  {
    rows,
    cols,
    board,
    selected: None,
    matchedPairs: 0,
    totalPairs: pairs,
  }
}

fn can_connect_direct(board: Array[Int], rows: Int, cols: Int, r1: Int, c1: Int, r2: Int, c2: Int) -> Bool {
  if r1 == r2 {
    let min_c = if c1 < c2 { c1 } else { c2 }
    let max_c = if c1 > c2 { c1 } else { c2 }
    let mut c = min_c + 1
    while c < max_c {
      if !is_empty(board, rows, cols, r1, c) {
        return false
      }
      c = c + 1
    }
    return true
  }
  if c1 == c2 {
    let min_r = if r1 < r2 { r1 } else { r2 }
    let max_r = if r1 > r2 { r1 } else { r2 }
    let mut r = min_r + 1
    while r < max_r {
      if !is_empty(board, rows, cols, r, c1) {
        return false
      }
      r = r + 1
    }
    return true
  }
  false
}

fn can_connect_one_corner(
  board: Array[Int],
  rows: Int,
  cols: Int,
  r1: Int,
  c1: Int,
  r2: Int,
  c2: Int,
) -> Option[(Int, Int)] {
  if is_empty(board, rows, cols, r1, c2) {
    if can_connect_direct(board, rows, cols, r1, c1, r1, c2) &&
       can_connect_direct(board, rows, cols, r1, c2, r2, c2) {
      return Some((r1, c2))
    }
  }
  if is_empty(board, rows, cols, r2, c1) {
    if can_connect_direct(board, rows, cols, r1, c1, r2, c1) &&
       can_connect_direct(board, rows, cols, r2, c1, r2, c2) {
      return Some((r2, c1))
    }
  }
  None
}

fn can_connect_two_corners(
  board: Array[Int],
  rows: Int,
  cols: Int,
  r1: Int,
  c1: Int,
  r2: Int,
  c2: Int,
) -> Option[(Int, Int, Int, Int)] {
  let mut c = -1
  while c <= cols {
    if c != c1 && c != c2 {
      if (c == -1 || c == cols || is_empty(board, rows, cols, r1, c)) &&
         (c == -1 || c == cols || is_empty(board, rows, cols, r2, c)) {
        let ok1 = can_connect_direct_virtual(board, rows, cols, r1, c1, r1, c)
        let ok2 = can_connect_direct_virtual(board, rows, cols, r1, c, r2, c)
        let ok3 = can_connect_direct_virtual(board, rows, cols, r2, c, r2, c2)
        if ok1 && ok2 && ok3 {
          return Some((r1, c, r2, c))
        }
      }
    }
    c = c + 1
  }
  let mut r = -1
  while r <= rows {
    if r != r1 && r != r2 {
      if (r == -1 || r == rows || is_empty(board, rows, cols, r, c1)) &&
         (r == -1 || r == rows || is_empty(board, rows, cols, r, c2)) {
        let ok1 = can_connect_direct_virtual(board, rows, cols, r1, c1, r, c1)
        let ok2 = can_connect_direct_virtual(board, rows, cols, r, c1, r, c2)
        let ok3 = can_connect_direct_virtual(board, rows, cols, r, c2, r2, c2)
        if ok1 && ok2 && ok3 {
          return Some((r, c1, r, c2))
        }
      }
    }
    r = r + 1
  }
  None
}

fn can_connect_direct_virtual(
  board: Array[Int],
  rows: Int,
  cols: Int,
  r1: Int,
  c1: Int,
  r2: Int,
  c2: Int,
) -> Bool {
  if r1 == r2 {
    let min_c = if c1 < c2 { c1 } else { c2 }
    let max_c = if c1 > c2 { c1 } else { c2 }
    let mut c = min_c + 1
    while c < max_c {
      if c >= 0 && c < cols && !is_empty(board, rows, cols, r1, c) {
        return false
      }
      c = c + 1
    }
    return true
  }
  if c1 == c2 {
    let min_r = if r1 < r2 { r1 } else { r2 }
    let max_r = if r1 > r2 { r1 } else { r2 }
    let mut r = min_r + 1
    while r < max_r {
      if r >= 0 && r < rows && !is_empty(board, rows, cols, r, c1) {
        return false
      }
      r = r + 1
    }
    return true
  }
  false
}

pub fn find_path(
  board: Array[Int],
  rows: Int,
  cols: Int,
  r1: Int,
  c1: Int,
  r2: Int,
  c2: Int,
) -> PathResult {
  if r1 == r2 && c1 == c2 {
    return { found: false, points: [] }
  }
  if get_at(board, rows, cols, r1, c1) != get_at(board, rows, cols, r2, c2) {
    return { found: false, points: [] }
  }
  if is_empty(board, rows, cols, r1, c1) || is_empty(board, rows, cols, r2, c2) {
    return { found: false, points: [] }
  }
  if can_connect_direct(board, rows, cols, r1, c1, r2, c2) {
    let pts: Array[Point] = []
    pts.push(point_new(c1, r1))
    pts.push(point_new(c2, r2))
    return { found: true, points: pts }
  }
  match can_connect_one_corner(board, rows, cols, r1, c1, r2, c2) {
    Some((cr, cc)) => {
      let pts: Array[Point] = []
      pts.push(point_new(c1, r1))
      pts.push(point_new(cc, cr))
      pts.push(point_new(c2, r2))
      return { found: true, points: pts }
    }
    _ => ()
  }
  match can_connect_two_corners(board, rows, cols, r1, c1, r2, c2) {
    Some((r1a, c1a, r2a, c2a)) => {
      let pts: Array[Point] = []
      pts.push(point_new(c1, r1))
      pts.push(point_new(c1a, r1a))
      pts.push(point_new(c2a, r2a))
      pts.push(point_new(c2, r2))
      return { found: true, points: pts }
    }
    _ => ()
  }
  { found: false, points: [] }
}

pub fn handle_click(state: GameState, r: Int, c: Int) -> (GameState, PathResult) {
  if r < 0 || r >= state.rows || c < 0 || c >= state.cols {
    return (state, { found: false, points: [] })
  }
  if is_empty(state.board, state.rows, state.cols, r, c) {
    return (state, { found: false, points: [] })
  }
  match state.selected {
    None => {
      let new_state = { ..state, selected: Some((r, c)) }
      (new_state, { found: false, points: [] })
    }
    Some((sr, sc)) => {
      if sr == r && sc == c {
        let new_state = { ..state, selected: None }
        (new_state, { found: false, points: [] })
      } else {
        let result = find_path(state.board, state.rows, state.cols, sr, sc, r, c)
        if result.found {
          set_at(state.board, state.rows, state.cols, sr, sc, 0)
          set_at(state.board, state.rows, state.cols, r, c, 0)
          let new_state = {
            ..state,
            selected: None,
            matchedPairs: state.matchedPairs + 1,
          }
          (new_state, result)
        } else {
          let new_state = { ..state, selected: Some((r, c)) }
          (new_state, { found: false, points: [] })
        }
      }
    }
  }
}

pub fn is_game_won(state: GameState) -> Bool {
  state.matchedPairs >= state.totalPairs
}

pub fn get_board(state: GameState) -> Array[Int] {
  state.board
}

pub fn get_rows(state: GameState) -> Int {
  state.rows
}

pub fn get_cols(state: GameState) -> Int {
  state.cols
}

pub fn get_selected(state: GameState) -> Option[(Int, Int)] {
  state.selected
}

pub fn get_matched_pairs(state: GameState) -> Int {
  state.matchedPairs
}

pub fn get_total_pairs(state: GameState) -> Int {
  state.totalPairs
}

pub fn get_board_value(state: GameState, r: Int, c: Int) -> Int {
  get_at(state.board, state.rows, state.cols, r, c)
}

pub fn get_selected_r(state: GameState) -> Int {
  match state.selected {
    Some((r, _)) => r
    None => -1
  }
}

pub fn get_selected_c(state: GameState) -> Int {
  match state.selected {
    Some((_, c)) => c
    None => -1
  }
}

pub fn path_found(result: PathResult) -> Bool {
  result.found
}

pub fn path_len(result: PathResult) -> Int {
  result.points.length()
}

pub fn path_point_x(result: PathResult, i: Int) -> Int {
  if i >= 0 && i < result.points.length() {
    result.points[i].x
  } else {
    -1
  }
}

pub fn path_point_y(result: PathResult, i: Int) -> Int {
  if i >= 0 && i < result.points.length() {
    result.points[i].y
  } else {
    -1
  }
}

pub fn click_get_state(result: (GameState, PathResult)) -> GameState {
  result.0
}

pub fn click_get_path(result: (GameState, PathResult)) -> PathResult {
  result.1
}

pub fn has_valid_moves(state: GameState) -> Bool {
  let tiles: Array[(Int, Int, Int)] = []
  let mut r = 0
  while r < state.rows {
    let mut c = 0
    while c < state.cols {
      let v = get_at(state.board, state.rows, state.cols, r, c)
      if v != 0 {
        tiles.push((r, c, v))
      }
      c = c + 1
    }
    r = r + 1
  }
  let n = tiles.length()
  let mut i = 0
  while i < n {
    let (r1, c1, v1) = tiles[i]
    let mut j = i + 1
    while j < n {
      let (r2, c2, v2) = tiles[j]
      if v1 == v2 {
        let result = find_path(state.board, state.rows, state.cols, r1, c1, r2, c2)
        if result.found {
          return true
        }
      }
      j = j + 1
    }
    i = i + 1
  }
  false
}

pub fn shuffle_board(state: GameState) -> GameState {
  let tiles: Array[Int] = []
  let mut r = 0
  while r < state.rows {
    let mut c = 0
    while c < state.cols {
      let v = get_at(state.board, state.rows, state.cols, r, c)
      if v != 0 {
        tiles.push(v)
      }
      c = c + 1
    }
    r = r + 1
  }
  shuffle(tiles)
  let new_board: Array[Int] = []
  let total = state.rows * state.cols
  let mut idx = 0
  let mut k = 0
  while idx < total {
    let r_idx = idx / state.cols
    let c_idx = idx % state.cols
    let old_v = get_at(state.board, state.rows, state.cols, r_idx, c_idx)
    if old_v == 0 {
      new_board.push(0)
    } else {
      new_board.push(tiles[k])
      k = k + 1
    }
    idx = idx + 1
  }
  { ..state, board: new_board, selected: None }
}

fn main {
  let state = init_game(2, 2, 2)
  let _ = get_rows(state)
  let _ = get_cols(state)
  let _ = get_matched_pairs(state)
  let _ = get_total_pairs(state)
  let _ = get_board_value(state, 0, 0)
  let _ = get_selected_r(state)
  let _ = get_selected_c(state)
  let _ = is_game_won(state)
  let _ = has_valid_moves(state)
  let r1 = handle_click(state, 0, 0)
  let s1 = click_get_state(r1)
  let p1 = click_get_path(r1)
  let _ = path_found(p1)
  let _ = path_len(p1)
  let _ = path_point_x(p1, 0)
  let _ = path_point_y(p1, 0)
  let s2 = shuffle_board(s1)
  let b = get_board(s2)
  let _ = get_board(s1)
  let p2 = find_path(b, 2, 2, 0, 0, 1, 1)
  let _ = path_found(p2)
}
