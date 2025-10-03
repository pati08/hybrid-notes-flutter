{
  description = "Flutter Wayland dev environment (Linux)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    ,
    }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        # Flutter doesn’t fully work in pure builds — allow unfree if needed
        config.allowUnfree = true;
      };
    in
    {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          # Flutter & Dart
          flutter
          dart

          # Wayland & GL
          wayland
          wayland-protocols
          libxkbcommon
          mesa
          vulkan-loader
          gtk3
          atk
          pango
          cairo
          gdk-pixbuf
          libepoxy
          mesa.drivers

          # Needed for plugins & build tooling
          pkg-config
          cmake
          ninja
          clang
          llvm
          libz
          libz.dev
        ];

        # Flutter wants to write cache dirs, allow in nix-shell
        shellHook = ''
          echo "Flutter Wayland dev environment ready."
          echo "Run: flutter doctor"
          echo "To run apps with Wayland: flutter run -d linux"
        '';
      };
    });
}
