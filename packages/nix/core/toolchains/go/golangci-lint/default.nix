{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.core.toolchains.go.golangci-lint = {
    enable = lib.mkEnableOption "Enable golangci-lint support.";
    settings = lib.mkOption {
      type = with lib.types; attrsOf anything;
      default = { };
      description = "golangci-lint settings (see https://golangci-lint.run/usage/configuration/).";
    };
  };
  config =
    let
      goOpts = config.core.toolchains.go;
      opts = goOpts.golangci-lint;
    in
    lib.mkIf opts.enable {
      assertions = [
        {
          assertion = goOpts.enable;
          message = "Go toolchain support must be enabled to use golangci-lint support.";
        }
      ];
      packages = with pkgs; [
        golangci-lint
        gotools
      ];
      files.".golangci.yml".yaml =
        lib.foldl' lib.recursiveUpdate
          {
            version = "2";

            run = {
              timeout = "5m";
              go = lib.versions.majorMinor config.languages.go.version;
            };

            linters = {
              # Standard set: errcheck, govet, ineffassign, staticcheck, unused
              default = "standard";

              enable = [
                "bodyclose" # ensure http.Response.Body.Close()
                "errorlint" # correct error wrapping / %w usage
                "gocritic" # opinionated checks (style + diagnostics)
                "gocyclo" # cyclomatic complexity (explicitly requested)
                "gosec" # security audit
                "misspell" # English spelling
                "nakedret" # forbid naked returns
                "nilerr" # don't return nil after `err != nil`
                "nolintlint" # validate //nolint directives
                "prealloc" # slice preallocation hints
                "revive" # configurable golint replacement
                "unconvert" # unneeded type conversions
                "unparam" # unused function parameters
                "usestdlibvars" # prefer stdlib constants over magic strings
              ];

              settings = {
                # Shadow analyzer — catches shadowed `err` etc. (explicitly requested).
                govet.enable = [ "shadow" ];

                gocyclo.min-complexity = 15;

                revive.rules = [
                  {
                    name = "exported";
                    # Permit echox.Echox, gormx.Gormx, postgres.Postgres, sqlite.Sqlite —
                    # this stutter is the packages/go governance convention.
                    arguments = [ "disableStutteringCheck" ];
                  }
                ];

                # sql.DB / files / response bodies all satisfy io.Closer; one rule covers them.
                errcheck.exclude-functions = [ "(io.Closer).Close" ];

                # G104 already covered by errcheck.
                gosec.excludes = [ "G104" ];

                misspell.locale = "US";
              };

              exclusions.rules = [
                # Tests get a more relaxed bar — complex setups, _ = err on cleanup,
                # table-driven duplication, etc.
                {
                  path = "_test\\.go";
                  linters = [
                    "gocyclo"
                    "gosec"
                    "errcheck"
                    "prealloc"
                    "unparam"
                  ];
                }
              ];
            };
          }
          [
            opts.settings
          ];
    };
}
