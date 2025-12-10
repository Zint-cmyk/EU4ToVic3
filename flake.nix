{
  description = "EU4 to Victoria 3 Converter (flake)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    #self.submodules = true;
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    systems = ["x86_64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    packages = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};

      eu4tovic3 = pkgs.stdenv.mkDerivation {
        pname = "eu4tovic3";
        version = "git";

        src = self;

        nativeBuildInputs = with pkgs; [
          cmake
          git
          pkg-config
          patchelf
        ];

        buildInputs = with pkgs; [
          curl
          boost
          zlib
          libzip
          wxwidgets_3_3
        ];

        postPatch = ''
          patchShebangs .
          substituteInPlace CMakeLists.txt \
            --replace-fail 'COMMAND git rev-parse HEAD > Release-Linux/commit_id.txt' \
                           'COMMAND echo unknown > Release-Linux/commit_id.txt'
          substituteInPlace Fronter/Fronter/Source/Frames/Tabs/PathsTab.cpp \
            --replace-fail 'ToStdWstring()' 'ToStdString()'

          substituteInPlace Fronter/Fronter/Source/Frontend.cpp \
            --replace-fail 'menuBar->Append(menuFile, "&" + tr("MENUCONVERTER"));' \
                           'menuBar->Append(menuFile, wxString("&") + wxString(tr("MENUCONVERTER").c_str()));' \
            --replace-fail 'menuBar->Append(menuLanguages, "&" + tr("LANGUAGE"));' \
                           'menuBar->Append(menuLanguages, wxString("&") + wxString(tr("LANGUAGE").c_str()));' \
            --replace-fail 'menuBar->Append(menuHelp, "&" + tr("MENUPGCG"));' \
                           'menuBar->Append(menuHelp, wxString("&") + wxString(tr("MENUPGCG").c_str()));'
        '';

        #buildPhase = ''
        #  ./build_linux.sh
        #'';

        installPhase = ''
          mkdir -p $out/bin $out/lib

          cp /build/source/Release-Linux/EU4ToVic3/EU4ToVic3Converter \
             $out/bin/eu4tovic3

          cp /build/source/EU4ToVic3/Resources/librakaly.so $out/lib/
        '';

        preFixup = ''
          bin="$out/bin/eu4tovic3"
          if [ -x "$bin" ]; then
            oldRpath="$(patchelf --print-rpath "$bin" || echo "")"

            cleaned="$(
              printf '%s\n' "$oldRpath" \
                | tr ':' '\n' \
                | grep -v '^/build' \
                | paste -sd:
            )"

            if [ -n "$cleaned" ]; then
              newRpath="$cleaned:$out/lib"
            else
              newRpath="$out/lib"
            fi

            patchelf --set-rpath "$newRpath" "$bin"
          fi
        '';
      };
    in {
      inherit eu4tovic3;

      default = eu4tovic3;
    });
  };
}
