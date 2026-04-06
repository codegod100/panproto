//! Evaluation of Nickel, JSON, and YAML sources into [`TheoryDocument`].
//!
//! Three evaluation paths:
//! - **Nickel** (`.ncl`): evaluated via `nickel-lang`, then deserialized via `to_serde`
//! - **JSON** (`.json`): deserialized directly via `serde_json`
//! - **YAML** (`.yaml`, `.yml`): deserialized directly via `yaml_serde`
//!
//! The Nickel path provides contracts, merge composition, functions,
//! and imports. JSON/YAML are pass-through for simple cases.

use std::ffi::OsString;
use std::path::PathBuf;

use crate::document::TheoryDocument;
use crate::error::TheoryDslError;

/// The bundled Nickel contract library source.
///
/// Embedded at compile time via `include_str!` so that
/// `import "panproto/theory.ncl"` resolves without external files.
const THEORY_CONTRACT_SOURCE: &str = include_str!("../contracts/theory.ncl");

/// Evaluate a Nickel source string to a [`TheoryDocument`].
///
/// Sets up an import path so that `import "panproto/theory.ncl"` resolves
/// to the bundled contract library. Additional import paths can be
/// supplied for user-defined Nickel modules.
///
/// # Errors
///
/// Returns [`TheoryDslError::NickelEval`] if evaluation or contract
/// checking fails, or a deserialization error if the evaluated record
/// does not match [`TheoryDocument`].
pub fn eval_nickel(
    source: &str,
    import_paths: &[PathBuf],
) -> Result<TheoryDocument, TheoryDslError> {
    let contract_dir = write_bundled_contracts()?;
    let contract_path = contract_dir.path().as_os_str().to_os_string();

    let mut paths: Vec<OsString> = vec![contract_path];
    paths.extend(import_paths.iter().map(|p| p.as_os_str().to_os_string()));

    let mut ctx = nickel_lang::Context::new()
        .with_added_import_paths(paths)
        .with_source_name("theory.ncl".to_owned());

    let expr = ctx.eval_deep_for_export(source).map_err(|e| {
        let mut buf = Vec::new();
        let message = if e.format(&mut buf, nickel_lang::ErrorFormat::Text).is_ok() {
            String::from_utf8_lossy(&buf).into_owned()
        } else {
            format!("{e:?}")
        };
        TheoryDslError::NickelEval { message }
    })?;

    expr.to_serde::<TheoryDocument>()
        .map_err(|e| TheoryDslError::NickelEval {
            message: format!("deserialization failed: {e}"),
        })
}

/// Evaluate a JSON string to a [`TheoryDocument`].
///
/// # Errors
///
/// Returns [`TheoryDslError::Json`] if parsing fails.
pub fn eval_json(source: &str) -> Result<TheoryDocument, TheoryDslError> {
    Ok(serde_json::from_str(source)?)
}

/// Evaluate a YAML string to a [`TheoryDocument`].
///
/// # Errors
///
/// Returns [`TheoryDslError::Yaml`] if parsing fails.
pub fn eval_yaml(source: &str) -> Result<TheoryDocument, TheoryDslError> {
    yaml_serde::from_str(source).map_err(|e| TheoryDslError::Yaml {
        message: e.to_string(),
    })
}

/// Write the bundled contract library to a temp directory.
///
/// Creates `<tmpdir>/panproto/theory.ncl` so that Nickel's import
/// resolution finds it when users write `import "panproto/theory.ncl"`.
fn write_bundled_contracts() -> Result<tempfile::TempDir, std::io::Error> {
    let dir = tempfile::tempdir()?;
    let contract_dir = dir.path().join("panproto");
    std::fs::create_dir_all(&contract_dir)?;
    std::fs::write(contract_dir.join("theory.ncl"), THEORY_CONTRACT_SOURCE)?;
    Ok(dir)
}
