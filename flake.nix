{
  description = "Composable Common Lisp dataflow runtime";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.cl-prolog = {
    url = "github:takeokunn/cl-prolog";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.cl-weave = {
    url = "github:takeokunn/cl-weave";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  inputs.paredit-cli = {
    url = "github:takeokunn/paredit-cli";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      cl-prolog,
      cl-weave,
      paredit-cli,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems =
        function: nixpkgs.lib.genAttrs systems (system: function (import nixpkgs { inherit system; }));
      sourceFor =
        pkgs:
        pkgs.lib.cleanSourceWith {
          src = ./.;
          filter =
            path: type:
            (pkgs.lib.cleanSourceFilter path type)
            && !(
              pkgs.lib.hasSuffix ".fasl" (builtins.baseNameOf path)
              || pkgs.lib.hasSuffix ".core" (builtins.baseNameOf path)
            );
        };
    in
    {
      formatter = forAllSystems (pkgs: pkgs.nixfmt);

      packages = forAllSystems (pkgs: {
        default = pkgs.stdenvNoCC.mkDerivation {
          pname = "cl-dataflow";
          version = "0.2.0";
          src = sourceFor pkgs;
          dontBuild = true;
          installPhase = ''
            mkdir -p "$out/share/common-lisp/source/cl-dataflow"
            cp -R . "$out/share/common-lisp/source/cl-dataflow"
          '';
        };
      });

      checks = forAllSystems (
        pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
          src = sourceFor pkgs;
          # cl-prolog is architecture-independent Lisp source, and upstream now
          # ships Linux-only per-system packages, so reference the flake source
          # tree directly. Its cl-prolog.asd sits at the root, which the trailing
          # "//" recursive marker in CL_SOURCE_REGISTRY discovers on every system.
          prologSource = "${cl-prolog.outPath}//";
          weave = cl-weave.packages.${system}.default;
          sourceRegistry = "${prologSource}:${weave}/share/common-lisp/source//:$PWD//:";
          mkWeaveCheck =
            {
              name,
              arguments,
              artifacts ? [ ],
            }:
            pkgs.stdenvNoCC.mkDerivation {
              inherit name src;
              nativeBuildInputs = [ weave ];
              buildPhase = ''
                export HOME="$TMPDIR/home"
                export XDG_CACHE_HOME="$TMPDIR/cache"
                mkdir -p "$HOME" "$XDG_CACHE_HOME"
                export CL_SOURCE_REGISTRY="${sourceRegistry}"
                cl-weave ${pkgs.lib.escapeShellArgs arguments}
                ${pkgs.lib.concatMapStringsSep "\n" (
                  artifact: "test -e ${pkgs.lib.escapeShellArg artifact}"
                ) artifacts}
              '';
              installPhase = ''
                mkdir -p "$out"
                ${pkgs.lib.concatMapStringsSep "\n" (
                  artifact: "cp -R ${pkgs.lib.escapeShellArg artifact} \"$out/\""
                ) artifacts}
              '';
            };
        in
        {
          default = mkWeaveCheck {
            name = "cl-dataflow-tests";
            arguments = [
              "run"
              "cl-dataflow/test"
            ];
          };

          coverage = mkWeaveCheck {
            name = "cl-dataflow-coverage";
            arguments = [
              "run"
              "cl-dataflow/test"
              "--coverage"
              "--coverage-system"
              "cl-dataflow"
              "--coverage-min-expression"
              "84"
              "--coverage-min-branch"
              "100"
              "--coverage-output"
              "cl-dataflow.coverage"
              "--coverage-report-directory"
              "coverage/"
            ];
            artifacts = [
              "cl-dataflow.coverage"
              "coverage/"
            ];
          };

          paredit-lint = paredit-cli.lib.${system}.mkLintCheck {
            inherit src;
            name = "cl-dataflow-paredit-lint";
          };
        }
      );

      apps = forAllSystems (
        pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
          weave = cl-weave.packages.${system}.default;
          test = pkgs.writeShellApplication {
            name = "cl-dataflow-test";
            runtimeInputs = [ weave ];
            text = ''
              export CL_SOURCE_REGISTRY="${cl-prolog.outPath}//:${weave}/share/common-lisp/source//:$PWD//:''${CL_SOURCE_REGISTRY:-}"
              exec cl-weave run cl-dataflow/test "$@"
            '';
          };
        in
        {
          default = {
            type = "app";
            program = "${test}/bin/cl-dataflow-test";
          };
        }
      );

      devShells = forAllSystems (
        pkgs:
        let
          system = pkgs.stdenv.hostPlatform.system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.nixfmt
              pkgs.sbcl
              cl-weave.packages.${system}.default
              paredit-cli.packages.${system}.default
            ];
            shellHook = ''
              export CL_SOURCE_REGISTRY="${cl-prolog.outPath}//:${
                cl-weave.packages.${system}.default
              }/share/common-lisp/source//:$PWD//:''${CL_SOURCE_REGISTRY:-}"
            '';
          };
        }
      );
    };
}
