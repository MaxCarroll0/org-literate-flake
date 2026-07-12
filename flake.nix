{
  description = "Literate programming via org-mode: batch tangle and LaTeX/PDF export with tikz-cd and minted";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      eachSystem =
        f:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
          system: f system (import nixpkgs { inherit system; })
        );
    in
    {
      packages = eachSystem (
        system: pkgs: rec {
          fmt = pkgs.writeShellApplication {
            name = "fmt-org";
            text = ''
              if (( $# )); then files=("$@"); else mapfile -t files < <(git ls-files 2>/dev/null); fi
              for f in "''${files[@]}"; do
                [[ -f "$f" && "$f" =~ \.org$ ]] || continue
                sed -i 's/[ \t]*$//' "$f"
                if [ -s "$f" ] && [ -n "$(tail -c1 "$f")" ]; then echo >> "$f"; fi
              done
            '';
          };

          pre-commit-hook = pkgs.writeShellScript "fmt-pre-commit" ''
            set -euo pipefail
            mapfile -t staged < <(git diff --cached --name-only --diff-filter=ACM)
            (( ''${#staged[@]} )) || exit 0
            for fmt in fmt-lean fmt-agda fmt-isabelle fmt-fstar fmt-coq fmt-org fmt-ocaml; do
              command -v "$fmt" >/dev/null 2>&1 || continue
              "$fmt" "''${staged[@]}"
            done
            git add -- "''${staged[@]}"
          '';

          tex = pkgs.texliveMedium.withPackages (ps: [
            ps.tikz-cd
            ps.minted
            ps.latexmk
            ps.fontspec
            ps.dejavu
            ps.wrapfig
            ps.capt-of
            ps.ulem
            ps.upquote
            ps.collection-latexrecommended
            ps.xifthen
            ps.ifmtarg
            ps.polytable
            ps.lazylist
            ps.environ
            ps.trimspaces
          ]);

          tangle = pkgs.writeShellApplication {
            name = "tangle-org";
            runtimeInputs = [ pkgs.emacs-nox ];
            text = builtins.readFile ./scripts/tangle.sh;
          };

          doc = pkgs.writeShellApplication {
            name = "doc-org";
            runtimeInputs = [
              pkgs.emacs-nox
              tex
              tangle
              pkgs.python3Packages.pygments
            ];
            runtimeEnv.OX_SETUP = ./scripts/ox-setup.el;
            text = builtins.readFile ./scripts/doc.sh;
          };
        }
      );

      lib = eachSystem (
        system: pkgs: {
          mkBuild =
            {
              src,
              name ? "org-literate-build",
            }:
            pkgs.stdenv.mkDerivation {
              inherit name;
              src = nixpkgs.lib.cleanSourceWith {
                inherit src;
                filter =
                  path: _type:
                  !(builtins.elem (baseNameOf path) [
                    ".git"
                    ".lake"
                    ".direnv"
                    "_build"
                    "output"
                  ]);
              };
              buildPhase = ''
                export HOME="$TMPDIR"
                mkdir -p "$out"
                set +e
                ${self.packages.${system}.doc}/bin/doc-org > "$out/doc.log" 2>&1
                status=$?
                set -e
                if [ "$status" -eq 0 ]; then echo PASS > "$out/status"; else echo "FAIL ($status)" > "$out/status"; fi
                tail -n 20 "$out/doc.log"
                find . -name '*.pdf' -exec cp --parents {} "$out/" \;
              '';
              installPhase = "true";
            };
        }
      );

      devShells = eachSystem (
        system: pkgs: {
          default = pkgs.mkShell {
            packages = [
              pkgs.emacs-nox
              self.packages.${system}.tex
              pkgs.python3Packages.pygments
              pkgs.just
              pkgs.git
              self.packages.${system}.tangle
              self.packages.${system}.doc
              self.packages.${system}.fmt
            ];
            shellHook = ''
              if [ -d .git ] && [ ! -e .git/hooks/pre-commit ]; then
                install -m 755 ${self.packages.${system}.pre-commit-hook} .git/hooks/pre-commit
                echo "fmt pre-commit hook installed"
              fi
            '';
          };
        }
      );

      apps = eachSystem (
        system: pkgs: {
          tangle = {
            type = "app";
            program = "${self.packages.${system}.tangle}/bin/tangle-org";
          };
          doc = {
            type = "app";
            program = "${self.packages.${system}.doc}/bin/doc-org";
          };
          fmt = {
            type = "app";
            program = "${self.packages.${system}.fmt}/bin/fmt-org";
          };
        }
      );

      formatter = eachSystem (system: pkgs: pkgs.nixfmt-rfc-style);
    };
}
