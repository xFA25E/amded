{
  description = "Emacs package";

  inputs = {
    amded.flake = false;
    amded.url = "github:ft/amded";

    eldev.flake = false;
    eldev.url = "github:doublep/eldev/1.3.1";

    emacs-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    amded,
    eldev,
    emacs-overlay,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        self.overlays.eldev
        self.overlays.amded
        self.overlays.default
      ];
    };

    inherit (builtins) attrNames elemAt foldl' head map match readDir readFile;
    inherit (builtins) stringLength tail;
    inherit (pkgs.lib.lists) filter;
    inherit (pkgs.lib.sources) sourceFilesBySuffices;
    inherit (pkgs.lib.strings) hasSuffix removeSuffix;
    parse = pkgs.callPackage "${emacs-overlay}/parse.nix" {};

    names = filter (hasSuffix ".el") (attrNames (readDir self));
    name = removeSuffix ".el" (foldl' (acc: elm:
      if (stringLength elm) < (stringLength acc)
      then elm
      else acc) (head names) (tail names));
    mainFile = readFile "${self}/${name}.el";

    version = elemAt (match ".*\n;; Version: ([^\n]+).*" mainFile) 0;
    url = elemAt (match ".*\n;; URL: ([^\n]+).*" mainFile) 0;
    deps = parse.parsePackagesFromPackageRequires mainFile;
  in {
    overlays = {
      default = final: prev: {
        emacsPackagesFor = emacs:
          (prev.emacsPackagesFor emacs).overrideScope' (
            efinal: eprev: {
              ${name} = efinal.melpaBuild {
                inherit version;
                pname = name;
                src = self;
                commit = self.rev or "f54a7ab2de88aee8aa5e7187bdddc28b425acbc9";
                recipe = final.writeText "recipe" ''
                  (${name} :fetcher git :url "${url}")
                '';
                packageRequires = map (dep: efinal.${dep}) deps;
              };
            }
          );
      };

      amded = final: prev: {
        amded = final.callPackage ({
          fetchFromGitHub,
          jsoncpp,
          libb64,
          pkg-config,
          stdenv,
          taglib,
          zlib,
        }:
          stdenv.mkDerivation {
            pname = "amded";
            version = builtins.head (builtins.match
              ".*\n#define VERSION \"([.0-9]+)\".*"
              (builtins.readFile "${amded}/amded.h"));
            src = amded;
            nativeBuildInputs = [pkg-config];
            buildInputs = [jsoncpp libb64 taglib zlib];
            makeFlags = ["PREFIX=$(out)"];
            ADDTOCXXFLAGS = "-Wno-deprecated-declarations -DBUFFERSIZE=BUFSIZ";
          }) {};
      };

      eldev = final: prev: {
        eldev = final.stdenv.mkDerivation {
          name = "eldev";
          src = eldev;
          dontUnpack = true;
          dontPatch = true;
          dontConfigure = true;
          dontBuild = true;
          nativeBuildInputs = [final.emacs];
          installPhase = ''
            mkdir -p $out/bin
            cp $src/bin/eldev $out/bin/
          '';
        };
      };
    };

    devShells.${system}.default = pkgs.mkShell {
      inherit name;
      buildInputs = [pkgs.alejandra pkgs.eldev pkgs.statix];
      shellHook = ''
        export ELDEV_DIR=$PWD/.eldev
      '';
    };

    packages.${system} =
      emacs-overlay.inputs.flake-utils.lib.flattenTree
      {
        inherit (pkgs) amded;
        emacsPackages = pkgs.lib.recurseIntoAttrs {
          ${name} = (pkgs.emacsPackagesFor pkgs.emacs).${name};
        };
      };

    checks.${system} =
      self.packages.${system}
      // {
        tests =
          pkgs.runCommand "run-tests" {
            nativeBuildInputs = [pkgs.amded];
          } ''
            cp ${sourceFilesBySuffices ./. [".el"]}/* .
            loadfiles=""
            for file in *.el ; do
              loadfiles="$loadfiles -l $file"
            done
            ${pkgs.emacs}/bin/emacs -Q -module-assertions -batch \
              -L . $loadfiles -f ert-run-tests-batch-and-exit \
              && touch $out
          '';
      };
  };
}
