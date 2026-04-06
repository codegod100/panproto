//! Compile a [`MorphismSpec`] into a [`TheoryMorphism`].
//!
//! Resolves domain and codomain theories, constructs the morphism,
//! and validates it via [`panproto_gat::check_morphism`].

use std::collections::HashMap;
use std::sync::Arc;

use panproto_gat::{Theory, TheoryMorphism};

use crate::document::MorphismSpec;
use crate::error::TheoryDslError;

/// Compile a [`MorphismSpec`] into a validated [`TheoryMorphism`].
///
/// The `resolver` callback looks up theories by name (both from the
/// local document and from external/built-in registries).
///
/// # Errors
///
/// Returns [`TheoryDslError::TheoryNotFound`] if domain or codomain
/// cannot be resolved, or [`TheoryDslError::MorphismCheck`] if the
/// morphism fails validation.
pub fn compile_morphism(
    spec: &MorphismSpec,
    resolver: &dyn Fn(&str) -> Option<Theory>,
) -> Result<TheoryMorphism, TheoryDslError> {
    let domain = resolver(&spec.domain).ok_or_else(|| TheoryDslError::TheoryNotFound {
        name: spec.domain.clone(),
        context: format!("morphism '{}' domain", spec.morphism),
    })?;

    let codomain = resolver(&spec.codomain).ok_or_else(|| TheoryDslError::TheoryNotFound {
        name: spec.codomain.clone(),
        context: format!("morphism '{}' codomain", spec.morphism),
    })?;

    let sort_map: HashMap<Arc<str>, Arc<str>> = spec
        .sort_map
        .iter()
        .map(|(k, v)| (Arc::from(k.as_str()), Arc::from(v.as_str())))
        .collect();

    let op_map: HashMap<Arc<str>, Arc<str>> = spec
        .op_map
        .iter()
        .map(|(k, v)| (Arc::from(k.as_str()), Arc::from(v.as_str())))
        .collect();

    let morphism = TheoryMorphism::new(
        spec.morphism.as_str(),
        spec.domain.as_str(),
        spec.codomain.as_str(),
        sort_map,
        op_map,
    );

    panproto_gat::check_morphism(&morphism, &domain, &codomain).map_err(|e| {
        TheoryDslError::MorphismCheck {
            morphism: spec.morphism.clone(),
            message: e.to_string(),
        }
    })?;

    Ok(morphism)
}
