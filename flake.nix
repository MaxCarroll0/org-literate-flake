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
              pkgs.gnumake
              pkgs.git
              self.packages.${system}.tangle
              self.packages.${system}.doc
            ];
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
        }
      );
    };
}
