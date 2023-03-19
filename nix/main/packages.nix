{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs self;
  l = inputs.nixpkgs.lib // builtins;
  meta = inputs.cells.automation.lib;
  epkgs = (nixpkgs.appendOverlays [inputs.emacs-overlay.overlay]).emacs.pkgs;
in {
  default = cell.packages."emacsPackages/${meta.name}";
  "emacsPackages/${meta.name}" = epkgs.melpaBuild {
    inherit (meta) version;
    pname = meta.name;
    src = self;
    commit = self.rev or "0000000000000000000000000000000000000000";
    recipe = nixpkgs.writeText "recipe" ''
      (${meta.name} :fetcher git :url "${meta.url}")
    '';
    packageRequires = l.attrsets.attrVals meta.deps epkgs;
  };

  amded = nixpkgs.stdenv.mkDerivation {
    pname = "amded";
    version = l.head (l.match
      ".*\n#define VERSION \"([.0-9]+)\".*"
      (l.readFile "${inputs.amded}/amded.h"));
    src = inputs.amded;
    nativeBuildInputs = [nixpkgs.pkg-config];
    buildInputs = [nixpkgs.jsoncpp nixpkgs.libb64 nixpkgs.taglib nixpkgs.zlib];
    makeFlags = ["PREFIX=$(out)"];
    ADDTOCXXFLAGS = "-Wno-deprecated-declarations -DBUFFERSIZE=BUFSIZ";
  };
}
