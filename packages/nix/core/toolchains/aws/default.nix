{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.core.toolchains.aws = {
    enable = lib.mkEnableOption "Enable AWS toolchain";
  };
  config =
    let
      opts = config.core.toolchains.aws;
    in
    lib.mkIf opts.enable {
      packages = with pkgs; [
        awscli2
        aws-vault
      ];

      core.ai.tools.aws = {
        permissions = [
          "Bash(aws:*)"
          "Bash(aws-vault:*)"
        ];
        sections = {
          toolGuidelines = ''
            ### Infrastructure tracing (AWS)

            - Only inspect AWS / CloudWatch when the task mentions production behaviour, bugs in deployed environments, infra changes, deployment, alarms, queues, lambdas, ECS, RDS, SQS, SNS, or similar concerns. Skip otherwise.
            - Use the `aws` CLI in **read-only** mode: `describe-*`, `list-*`, `get-*`, `filter-log-events`, `lookup-events`, `search-logs`.
            - **NEVER** mutate cloud resources. No `create-*`, `update-*`, `delete-*`, `put-*`, `deploy-*`, `start-*`, `stop-*`, `reboot-*`, `terminate-*`.
            - Cite the AWS region, account ID, resource ARN, and timestamp on every datum. CloudWatch evidence must include the log group, stream, and `@timestamp` of each cited line.
            - Heavy AWS evidence (raw log dumps, metric series) MUST be saved as sibling files alongside the finding, never inlined into the finding body. The docs module owns the exact heavy-evidence layout convention.
          '';
        };
        order = 80;
      };
    };
}
