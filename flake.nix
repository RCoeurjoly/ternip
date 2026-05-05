{
  description = "Ternip RTL accelerator";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    basejump-stl = {
      url =
        "github:bespoke-silicon-group/basejump_stl/a43571d2eaaae2dda7c10490e8350dfdac7da878";
      flake = false;
    };
    yosys-slang = {
      url = "git+https://github.com/povik/yosys-slang?submodules=1";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, basejump-stl, yosys-slang }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          yosysPkg = pkgs.yosys;
          yosysPkgWithPythonEnv = if yosysPkg ? python3-env then
            yosysPkg
          else
            (yosysPkg // { python3-env = pkgs.python3; });
          yosysSlang = pkgs.clangStdenv.mkDerivation {
            pname = "yosys-slang";
            version = "flake-input";
            src = yosys-slang;
            dylibs = [ "slang" ];
            cmakeFlags = [
              "-DYOSYS_CONFIG=${yosysPkgWithPythonEnv}/bin/yosys-config"
              "-DFMT_INSTALL:BOOL=OFF"
            ];
            nativeBuildInputs = [ pkgs.cmake pkgs.jq ];
            buildInputs = [
              yosysPkgWithPythonEnv
              yosysPkgWithPythonEnv.python3-env
              pkgs.fmt
            ];
            patchPhase = ''
              runHook prePatch
              sed -i \
                -e '/git_rev_parse(YOSYS_SLANG_REVISION/c\set(YOSYS_SLANG_REVISION flake-input)' \
                -e '/git_rev_parse(SLANG_REVISION/c\set(SLANG_REVISION flake-input-submodule)' \
                src/CMakeLists.txt
              runHook postPatch
            '';
            cmakeBuildType = "Release";
            installPhase = ''
              runHook preInstall
              mkdir -p $out/share/yosys/plugins
              cp ../build/slang.so $out/share/yosys/plugins/
              runHook postInstall
            '';
          };
        in {
          reduced-verilator-lint-report =
            pkgs.runCommand "ternip-reduced-verilator-lint-report" {
              nativeBuildInputs = [ pkgs.verilator ];
            } ''
              set -euo pipefail
              mkdir -p "$out"
              cd ${self}
              set +e
              BASEJUMP_STL=${basejump-stl} \
                ${pkgs.bash}/bin/bash scripts/lint_reduced_verilator.sh \
                  > "$out/lint.log" 2>&1
              rc=$?
              set -e
              status=PASS
              if [ "$rc" -ne 0 ]; then
                status=FAIL
              fi
              cat > "$out/summary.json" <<EOF
              {
                "artifact_name": "ternip-reduced-verilator-lint-report",
                "status": "$status",
                "verilator_exit_code": $rc,
                "config": "config/reduced_ypcb.svh",
                "basejump_stl": "a43571d2eaaae2dda7c10490e8350dfdac7da878",
                "next_gate": "If PASS, add a synthesis gate; if FAIL, fix the first lint blocker without changing board integration."
              }
              EOF
            '';

          reduced-yosys-synth-report =
            pkgs.runCommand "ternip-reduced-yosys-synth-report" {
              nativeBuildInputs = [ yosysPkg yosysSlang ];
            } ''
              set -euo pipefail
              mkdir -p "$out"
              cp -r ${self} ternip-src
              chmod -R u+w ternip-src
              cd ternip-src
              set +e
              BASEJUMP_STL=${basejump-stl} \
                YOSYS=${yosysPkg}/bin/yosys \
                YOSYS_SLANG_SO=${yosysSlang}/share/yosys/plugins/slang.so \
                ${pkgs.bash}/bin/bash scripts/synth_reduced_yosys.sh \
                  "$out/ternip-reduced-synth.json" \
                  "$out/stat.json" \
                  > "$out/synth.log" 2>&1
              rc=$?
              set -e
              status=PASS
              if [ "$rc" -ne 0 ]; then
                status=FAIL
              fi
              cat > "$out/summary.json" <<EOF
              {
                "artifact_name": "ternip-reduced-yosys-synth-report",
                "status": "$status",
                "yosys_exit_code": $rc,
                "config": "config/reduced_ypcb.svh",
                "basejump_stl": "a43571d2eaaae2dda7c10490e8350dfdac7da878",
                "synth_json": "ternip-reduced-synth.json",
                "stat_json": "stat.json",
                "next_gate": "If PASS, inspect utilization and add a YPCB wrapper gate; if FAIL, fix the first synthesis blocker."
              }
              EOF
            '';

          default = self.packages.${system}.reduced-verilator-lint-report;
        });

      checks = forAllSystems (system: {
        reduced-verilator-lint =
          self.packages.${system}.reduced-verilator-lint-report;
        reduced-yosys-synth =
          self.packages.${system}.reduced-yosys-synth-report;
      });

      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            packages = [ pkgs.verilator pkgs.yosys ];
            BASEJUMP_STL = basejump-stl;
          };
        });
    };
}
