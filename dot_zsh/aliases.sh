# Shell aliases — sourced by both zsh and bash
# Managed via chezmoi (architr/dotfiles)

# Replace ls with eza
alias ld="eza -lD"
alias lf="eza -lf --color=always"
alias lh="eza -dl .* --group-directories-first"
alias ll="eza -al --group-directories-first"
alias ls="eza -alf --color=always --sort=size"
alias lt='eza -al --sort=modified'

# Spin up mydatas
alias gpu-up="pay -t mydata-gpu-g3 up"
alias hmem-up="pay -t mydata-highmem up"
alias mydata-up="pay -t mydata-standard up"
alias flyte-up="pay -t myflytebox up"

# SSH into mydatas
alias gpu-ssh="pay -t mydata-gpu-g3 ssh"
alias hmem-ssh="pay -t mydata-highmem ssh"
alias mydata-ssh="pay -t mydata-standard ssh"
alias flyte-ssh="pay -t myflytebox ssh"

# parquet utils
alias parquet-schema="pay --name mydata-1 exec parquet-schema"
alias parquet-head="pay --name mydata-1 exec parquet-head"
alias parquet-count="pay --name mydata-1 exec parquet-count"

# AWS QoL commands
alias awsls="pay --name mydata-1 exec aws s3 ls --summarize --human-readable"
alias awsrm="pay --name mydata-1 exec aws s3 rm --recursive"

# Lazygit
alias lg="lazygit"

# Bazel utilities
alias test_detailed="pay --name mydata-1 test --test_output=streamed --test_summary=detailed"

# Frequently used Flyte commands
alias wf_register="./scripts/ml/flyte/register_workflow.py"
alias wf_register_ci="pay flyte-register --workflow"
alias flyteumain="echo Setting myflytebox universe to main && pay -t myflytebox ssh source ./bin/py-universe main"
alias register_backtest="./scripts/ml/flyte/register_workflow.py //src/python/flyte/fraud_intelligence/models/backtest"
alias register_prod_training="./scripts/ml/flyte/register_workflow.py //src/python/flyte/fraud_intelligence/models/prod_training"
alias image_list="pay -t myflytebox ssh docker image list"

alias jupyter_upgrade="echo Upgrading Jupyter to latest version on mydata-standard && pay exec pip install --upgrade jupyter jupyterlab ipykernel && echo Upgrade complete. Refresh HNB for changes to take effect"
alias jupyter_upgrade_g3="echo Upgrading Jupyter to latest version on mydata-gpu-g3 && pay -t mydata-gpu-g3 exec pip install --upgrade jupyter jupyterlab ipykernel && echo Upgrade complete. Refresh HNB for changes to take effect"
alias jupyter_upgrade_hmem="echo Upgrading Jupyter to latest version on mydata-highmem && pay -t mydata-highmem exec pip install --upgrade jupyter jupyterlab ipykernel && echo Upgrade complete. Refresh HNB for changes to take effect"

# Chronon/Shepherd commands
alias validate-join="pay exec ./tools/scripts/experimental/chronon_poc/chronon_cli.py validate-join --join-name"
alias run-join="pay exec ./tools/scripts/experimental/chronon_poc/chronon_cli.py join --executors 1000 --join-name"

# Linting and typechecking
alias zoo-lint="cd ~/stripe/zoolander/ && pay zoo:lint --fix"
alias typecheck="./dev/py check --with-typechecking --fix"

# AI tools
alias cc_yolo="claude --dangerously-skip-permissions"
alias cx_yolo="codex --yolo"
alias oc="opencode"

# diorama model info
model-info ()
{
  local show_features=false

  # Parse arguments
  while [ $# -gt 0 ]; do
    case $1 in
      --show-feats)
        show_features=true
        shift
        ;;
      *)
        model_sha=$1
        shift
        ;;
    esac
  done

  if [ "$show_features" = true ]; then
    pay exec diorama-tool to-model-info-response --dioramaId $model_sha 2>/dev/null | jq
  else
    pay exec diorama-tool to-model-info-response --dioramaId $model_sha 2>/dev/null | jq 'del(.features)'
  fi
}
