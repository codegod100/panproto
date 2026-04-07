{
  description = "Panproto - Schematic version control toolkit based on generalized algebraic theories";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };

        # Read the Rust toolchain version from rust-toolchain.toml
        rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;

        # Common build inputs for all packages
        nativeBuildInputs = with pkgs; [
          rustToolchain
          pkg-config
          cmake
          perl
          python3
          nasm
          llvmPackages.llvm
          llvmPackages.clang
        ];

        buildInputs = with pkgs; [
          openssl
          libgit2
          zlib
        ] ++ lib.optionals stdenv.isDarwin [
          libiconv
          darwin.apple_sdk.frameworks.Security
          darwin.apple_sdk.frameworks.CoreFoundation
        ];

        # Build the panproto workspace
        schema = pkgs.rustPlatform.buildRustPackage rec {
          pname = "schema";
          version = "0.27.0";
          src = ./.;

          cargoLock = {
            lockFile = ./Cargo.lock;
          };

          inherit nativeBuildInputs buildInputs;

          meta = with pkgs.lib; {
            description = "Schematic version control CLI for panproto";
            homepage = "https://github.com/panproto/panproto";
            license = licenses.mit;
            mainProgram = "schema";
          };
        };

        # Generate JSON schema for the CLI
        generateSchema = pkgs.writeShellScriptBin "generate-schema" ''
          set -e
          OUTPUT="''${1:-schema-cli-schema.json}"
          
          echo "Generating CLI schema for panproto..."
          
          # Generate schema using clap's JSON output capability
          # We create a comprehensive schema based on the CLI structure
          cat > "$OUTPUT" << 'SCHEMA'
        {
          "$schema": "https://json-schema.org/draft/2020-12/schema",
          "title": "Panproto CLI Configuration",
          "description": "Configuration schema for the panproto schematic version control CLI",
          "type": "object",
          "properties": {
            "verbose": {
              "type": "boolean",
              "description": "Enable verbose output",
              "default": false
            },
            "command": {
              "type": "string",
              "description": "Subcommand to execute",
              "enum": [
                "validate", "check", "scaffold", "normalize", "typecheck", "verify",
                "init", "add", "commit", "status", "log", "diff", "show",
                "branch", "tag", "checkout", "merge", "rebase", "cherry-pick",
                "reset", "stash", "reflog", "bisect", "blame", "gc",
                "lift", "integrate", "auto-migrate",
                "expr", "enrich", "remote", "push", "pull", "fetch", "clone",
                "data", "theory", "lens", "parse", "git"
              ]
            },
            "schema": {
              "type": "object",
              "description": "Schema validation and manipulation settings",
              "properties": {
                "protocol": {
                  "type": "string",
                  "description": "Protocol name (e.g., atproto)"
                },
                "path": {
                  "type": "string",
                  "description": "Path to schema JSON file"
                }
              }
            },
            "migration": {
              "type": "object",
              "description": "Migration settings",
              "properties": {
                "src": {
                  "type": "string",
                  "description": "Source schema path"
                },
                "tgt": {
                  "type": "string",
                  "description": "Target schema path"
                },
                "mapping": {
                  "type": "string",
                  "description": "Migration mapping file path"
                },
                "typecheck": {
                  "type": "boolean",
                  "description": "Type-check at GAT level",
                  "default": false
                }
              }
            },
            "vcs": {
              "type": "object",
              "description": "Version control settings",
              "properties": {
                "author": {
                  "type": "string",
                  "description": "Author name for commits",
                  "default": "anonymous"
                },
                "initial_branch": {
                  "type": "string",
                  "description": "Name for initial branch",
                  "default": "main"
                }
              }
            },
            "lens": {
              "type": "object",
              "description": "Bidirectional lens settings",
              "properties": {
                "direction": {
                  "type": "string",
                  "enum": ["forward", "backward"],
                  "default": "forward"
                },
                "fuse": {
                  "type": "boolean",
                  "description": "Fuse multi-step chain into single protolens",
                  "default": false
                },
                "defaults": {
                  "type": "array",
                  "items": { "type": "string" },
                  "description": "Default values as key=value pairs"
                }
              }
            },
            "data": {
              "type": "object",
              "description": "Data migration settings",
              "properties": {
                "dry_run": {
                  "type": "boolean",
                  "description": "Preview without modifying files",
                  "default": false
                },
                "backward": {
                  "type": "boolean",
                  "description": "Migrate backward",
                  "default": false
                }
              }
            }
          }
        }
        SCHEMA
          
          echo "Schema written to: $OUTPUT"
        '';

      in
      {
        packages = {
          default = schema;
          schema = schema;
          
          # Schema output - JSON schema for CLI configuration
          schema-config = pkgs.stdenv.mkDerivation {
            name = "panproto-cli-schema";
            version = "0.27.0";
            src = ./.;
            
            nativeBuildInputs = [ generateSchema ];
            
            buildPhase = ''
              generate-schema schema-cli-schema.json
            '';
            
            installPhase = ''
              mkdir -p $out/share/panproto
              cp schema-cli-schema.json $out/share/panproto/
              
              # Also create a top-level link for easy access
              mkdir -p $out
              cp schema-cli-schema.json $out/
            '';
          };
        };

        apps = {
          default = flake-utils.lib.mkApp {
            drv = schema;
            name = "schema";
          };
          schema = flake-utils.lib.mkApp {
            drv = schema;
            name = "schema";
          };
        };

        devShells.default = pkgs.mkShell {
          inherit nativeBuildInputs;
          
          buildInputs = buildInputs ++ (with pkgs; [
            rustToolchain
            rust-analyzer
            cargo-edit
            cargo-watch
            cargo-deny
            cargo-dist
            just
            pre-commit
            tree-sitter
          ]);

          RUST_BACKTRACE = 1;
          RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";
          LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
          
          shellHook = ''
            echo "🚀 Welcome to the panproto development shell!"
            echo "Rust toolchain: $(rustc --version)"
            echo "Cargo: $(cargo --version)"
            echo ""
            echo "Available commands:"
            echo "  schema --help          # CLI help"
            echo "  cargo build            # Build the workspace"
            echo "  cargo test             # Run tests"
            echo "  just --list            # List just tasks"
          '';
        };

        # Schema output for external tooling
        schema = {
          version = "0.27.0";
          schema = ./schema-cli-schema.json;
        };
      }) // {
        # System-independent outputs
        overlays.default = final: prev: {
          schema = self.packages.${prev.system}.schema;
        };

        homeManagerModules.default = { config, lib, pkgs, ... }: {
          options.programs.schema = {
            enable = lib.mkEnableOption "schema - schematic version control CLI";
            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.schema;
              description = "The schema CLI package to use";
            };
          };
          
          config = lib.mkIf config.programs.schema.enable {
            home.packages = [ config.programs.schema.package ];
          };
        };

        nixosModules.default = { config, lib, pkgs, ... }: {
          options.programs.schema = {
            enable = lib.mkEnableOption "schema - schematic version control CLI";
            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.schema;
              description = "The schema CLI package to use";
            };
          };
          
          config = lib.mkIf config.programs.schema.enable {
            environment.systemPackages = [ config.programs.schema.package ];
          };
        };
      };
}
