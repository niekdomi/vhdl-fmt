use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct FormatConfig {
    pub line_length: usize,
    pub indentation: IndentConfig,
    pub casing: CasingConfig,
}

impl Default for FormatConfig {
    fn default() -> Self {
        Self {
            line_length: 100,
            indentation: IndentConfig::default(),
            casing: CasingConfig::default(),
        }
    }
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct IndentConfig {
    pub size: usize,
}

impl Default for IndentConfig {
    fn default() -> Self {
        Self { size: 4 }
    }
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct CasingConfig {
    pub keywords: CasingMode,
    pub identifiers: CasingMode,
    pub constants: CasingMode,
}

impl Default for CasingConfig {
    fn default() -> Self {
        Self {
            keywords: CasingMode::Preserve,
            identifiers: CasingMode::Preserve,
            constants: CasingMode::Preserve,
        }
    }
}

#[derive(Debug, Clone, Default, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum CasingMode {
    #[default]
    Preserve,
    LowerCase,
    UpperCase,
}

impl CasingMode {
    pub fn apply(&self, s: &str) -> String {
        match self {
            CasingMode::Preserve => s.to_string(),
            CasingMode::LowerCase => s.to_lowercase(),
            CasingMode::UpperCase => s.to_uppercase(),
        }
    }
}
