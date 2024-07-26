import gleam/option.{type Option}

pub fn tuple2(a: a, b: b) -> #(a, b) {
  #(a, b)
}

pub fn twice_optional(start: a, f: fn(a) -> Option(a)) -> Option(#(a, a)) {
  use first <- option.then(f(start))
  f(first) |> option.map(tuple2(first, _))
}

pub fn combine(ma: Option(a), mb: Option(b)) -> Option(#(a, b)) {
  ma
  |> option.then(fn(a) { mb |> option.map(tuple2(a, _)) })
}
