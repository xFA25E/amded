{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
in {
  default = nixpkgs.mkShell {
    packages = [
      cell.packages.eldev
      inputs.cells.main.packages.amded
      nixpkgs.alejandra
      nixpkgs.statix
    ];
    shellHook = ''
      export ELDEV_DIR=$PWD/.eldev
    '';
  };
}
