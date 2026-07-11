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
