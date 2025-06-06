{
  inputs,
  self,
  ...
} @ args: {
  perSystem = {
    config,
    pkgs,
    lib,
    ...
  }: let
    docs = import ../docs {inherit pkgs inputs lib;};
    buildPkg = maximal:
      (args.config.flake.lib.nvim.neovimConfiguration {
        inherit pkgs;
        modules = [(import ../configuration.nix maximal)];
      }).neovim;
  in {
    packages = {
      blink-cmp = pkgs.callPackage ./blink {};
      avante-nvim = let
        pin = self.pins.avante-nvim;
      in
        pkgs.callPackage ./avante-nvim {
          version = pin.branch;
          src = pkgs.fetchFromGitHub {
            inherit (pin.repository) owner repo;
            rev = pin.revision;
            sha256 = pin.hash;
          };
          pins = self.pins;
        };

      inherit (docs.manual) htmlOpenTool;
      # Documentation
      docs = docs.manual.html;
      docs-html = docs.manual.html;
      docs-manpages = docs.manPages;
      docs-json = docs.options.json;
      docs-linkcheck = let
        site = config.packages.docs;
      in
        pkgs.testers.lycheeLinkCheck {
          inherit site;

          remap = {
            "https://notashelf.github.io/nvf/" = site;
          };

          extraConfig = {
            exclude = [];
            include_mail = true;
            include_verbatim = true;
          };
        };

      # Helper utility for building the HTML manual and opening it in the
      # browser with $BROWSER or using xdg-open as a fallback tool.
      # Adapted from Home-Manager, available under the MIT license.
      docs-html-wrapped = let
        xdg-open = lib.getExe' pkgs.xdg-utils "xdg-open";
        docs-html = docs.manual.html + /share/doc/nvf;
      in
        pkgs.writeShellScriptBin "docs-html-wrapped" ''
          set -euo pipefail

          if [[ ! -v BROWSER || -z $BROWSER ]]; then
            for candidate in xdg-open open w3m; do
            BROWSER="$(type -P $candidate || true)"
              if [[ -x $BROWSER ]]; then
                break;
              fi
            done
          fi

          if [[ ! -v BROWSER || -z $BROWSER ]]; then
            echo "$0: unable to start a web browser; please set \$BROWSER"
            echo "$0: Trying xdg-open as a fallback"
            ${xdg-open} ${docs-html}/index.xhtml
          else
            echo "\$BROWSER is set. Attempting to open manual"
            exec "$BROWSER" "${docs-html}/index.xhtml"
          fi
        '';

      # Exposed neovim configurations
      nix = buildPkg false;
      maximal = buildPkg true;
      default = config.packages.nix;
    };
  };
}
