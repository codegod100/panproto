# panproto-theory-dsl

[![crates.io](https://img.shields.io/crates/v/panproto-theory-dsl.svg)](https://crates.io/crates/panproto-theory-dsl)
[![docs.rs](https://docs.rs/panproto-theory-dsl/badge.svg)](https://docs.rs/panproto-theory-dsl)

Declarative theory DSL for panproto.

Provides a human-readable specification format for GAT theories, theory morphisms, compositions, and protocols. The primary authoring format is [Nickel](https://nickel-lang.org) (via `nickel-lang` 2.0), a typed configuration language with record merge for composition, functions for parameterized templates, contracts for validation, and imports for modularity. JSON and YAML are also supported for simpler cases.

## Evaluation pipeline

```
*.ncl / *.json / *.yaml   (human-authored)
         |
         v
    TheoryDocument         (normalized record)
         |
         v
Theory + TheoryMorphism + Protocol   (panproto algebra)
```

## Example (JSON)

```json
{
  "id": "dev.attitudes.base",
  "description": "Shared base theory for propositional attitudes",
  "theory": "ThAttBase",
  "sorts": [
    { "name": "Agent" },
    { "name": "Content" },
    { "name": "Prop", "params": [{ "name": "c", "sort": "Content" }] },
    { "name": "Asc", "params": [
      { "name": "a", "sort": "Agent" },
      { "name": "c", "sort": "Content" }
    ]}
  ],
  "ops": [
    { "name": "holder", "input": "Asc", "output": "Agent" },
    { "name": "content", "input": "Asc", "output": "Content" },
    { "name": "prop", "input": "Asc", "output": "Prop" }
  ]
}
```

## Example (Nickel)

```nickel
let T = import "panproto/theory.ncl" in

{
  id = "dev.attitudes.belief-class",
  description = "Belief class: conjunction + consistency + neg-raising",
  compose = {
    result = "ThBelief",
    bases = ["ThAttBase", "ThConjunction", "ThConsistency", "ThNegRaising"],
    steps = [
      T.colimit_with_ops "ThAttBase" "ThConjunction"
        ["Agent", "Content", "Prop", "Asc"]
        ["holder", "content", "prop"],
      T.colimit_with_ops "step_0" "ThConsistency"
        ["Agent", "Content", "Prop", "Asc"]
        ["holder", "content", "prop"],
      T.colimit_with_ops "step_1" "ThNegRaising"
        ["Agent", "Content", "Prop", "Asc"]
        ["holder", "content", "prop", "neg"],
    ],
  },
} | T.Composition
```

## API

| Item | Description |
|------|-------------|
| `load` | Load a theory document from a `.ncl`, `.json`, `.yaml`, or `.yml` file |
| `load_dir` | Load all theory documents from a directory, returning `LoadDirResult` with documents and per-file errors |
| `compile` | Compile a `TheoryDocument` to `Theory` + `TheoryMorphism` + `Protocol` via a resolver callback |
| `load_and_compile` | Load and compile in one step |
| `compile_bundle` | Compile a `BundleSpec` with dependency-ordered phases |
| `builtin_resolver` | Default resolver for panproto's 11 built-in theories |
| `TheoryDocument` | Deserialized theory specification with five body variants |
| `CompiledTheorySet` | Compilation output: theories, morphisms, protocols, and composition specs |
| `TheoryDslError` | Diagnostic errors (nickel eval, JSON, YAML, term parse, expression parse, typecheck, morphism check, colimit) |

## Body variants

| Variant | Description |
|---------|-------------|
| `theory` | Single theory definition with sorts, operations, equations, directed equations, and conflict policies |
| `morphism` | Theory morphism between two named theories with sort and operation mappings |
| `compose` | Ordered colimit steps over base theories producing a new composed theory |
| `protocol` | Full protocol definition with schema theory, instance theory, and edge rules |
| `bundle` | Multiple theories, morphisms, compositions, and protocols in one file |

## Nickel contract library

The bundled `contracts/theory.ncl` provides `Theory`, `Morphism`, `Composition`, `Protocol`, `Bundle` contracts and combinator functions: `simple`, `dependent`, `val_sort`, `param`, `unary`, `binary`, `nullary`, `eq`, `directed_eq`, `colimit`, `colimit_with_ops`, `edge_rule`, `keep_left`, `keep_right`, `fail_on_conflict`, `custom_policy`.

## CLI commands

```
schema theory validate <file>          # typecheck a theory document
schema theory compile <file>           # compile and print resulting theories
schema theory compile-dir <dir>        # compile a directory of theory files
schema theory check-morphism <file>    # validate a morphism document
schema theory recompose <file>         # replay a composition and print result
```
