{
  lib,
  ...
}:
let
  makePrimitiveOption =
    primitiveType:
    {
      description ? "",
      readOnly ? false,
      nullable ? false,
      default ? null,
      ...
    }:
    lib.mkOption (
      {
        inherit readOnly;
        type = if nullable then lib.types.nullOr primitiveType else primitiveType;

        description = if description != "" then description else "Value to be set";
      }
      // lib.optionalAttrs (default != null || nullable) {
        inherit default;
      }
    );

  utils = {
    inherit makePrimitiveOption;

    makePackageOption = inputs: makePrimitiveOption lib.types.package inputs;

    makeStrOption = inputs: makePrimitiveOption lib.types.str inputs;

    makeIntOption = inputs: makePrimitiveOption lib.types.int inputs;

    makeFloatOption = inputs: makePrimitiveOption lib.types.float inputs;

    makeBoolOption = inputs: makePrimitiveOption lib.types.bool inputs;

    makePathOption = inputs: makePrimitiveOption lib.types.path inputs;

    makeEnumOption =
      {
        acceptedList ? [ ],
        ...
      }@inputs:
      makePrimitiveOption (lib.types.enum acceptedList) inputs;

    makeListOption =
      {
        ofType ? lib.types.anything,
        ...
      }@inputs:
      makePrimitiveOption (lib.types.listOf ofType) inputs;

    makeAttrsOption =
      {
        ofType ? lib.types.anything,
        ...
      }@inputs:
      makePrimitiveOption (lib.types.attrsOf ofType) inputs;

    failWhen =
      { condition, message, ... }:
      {
        assertion = condition == false;
        inherit message;
      };
  };
in
{
  options.core.utils = lib.mkOption {
    type = lib.types.anything;
    readOnly = true;
    default = utils;
    description = "Core utility helpers for module options and assertions.";
  };
}
