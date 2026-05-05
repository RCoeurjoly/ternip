{
  description = "Ternip RTL accelerator";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    basejump-stl = {
      url =
        "github:bespoke-silicon-group/basejump_stl/a43571d2eaaae2dda7c10490e8350dfdac7da878";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, basejump-stl }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      packages = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
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

          default = self.packages.${system}.reduced-verilator-lint-report;
        });

      checks = forAllSystems (system: {
        reduced-verilator-lint =
          self.packages.${system}.reduced-verilator-lint-report;
      });

      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            packages = [ pkgs.verilator ];
            BASEJUMP_STL = basejump-stl;
          };
        });
    };
}
