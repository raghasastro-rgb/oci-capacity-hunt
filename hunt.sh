#!/usr/bin/env bash
# One attempt at launching the instance. Exits 0 for every expected outcome —
# capacity refusals are the normal case, and a red X every ten minutes would
# train the owner to ignore the one run that matters.
set -uo pipefail

# Every message goes to the run log as well as the step summary. The script
# exits 0 on a capacity refusal, so `gh run list` shows the same green tick
# whether Oracle said no or handed over a machine; the reason has to be
# greppable from the log for the outcome to be readable without the browser.
say() { echo "$*"; echo "$*" >> "$GITHUB_STEP_SUMMARY"; }
out() { echo "$1=$2" >> "$GITHUB_OUTPUT"; }

# Never launch a second instance. This is the guard that makes a scheduled
# hunt safe: if a machine already exists — created by this workflow, by the
# laptop hunter, or by hand in the console — the run stops here.
existing=$(oci compute instance list \
  --compartment-id "$COMPARTMENT" \
  --display-name powgrove \
  --query 'data[?"lifecycle-state"!=`TERMINATED`].id' \
  --raw-output 2>/dev/null)

if [ -n "$existing" ] && [ "$existing" != "[]" ]; then
  say "An instance already exists — nothing to hunt."
  out result exists
  exit 0
fi

# Alternate shapes between runs: 2 OCPU / 12 GB — half the Always Free ARM
# allowance, and a far easier ask than the whole of it, because a fragmented
# host can satisfy two cores when it can never satisfy four — then 1 OCPU /
# 6 GB. A1.Flex resizes upward later (stop, change shape config, start), so
# taking the smaller machine now forfeits nothing permanent.
if [ $((RUN_NUMBER % 2)) -eq 1 ]; then
  ocpus=2; memory=12
else
  ocpus=1; memory=6
fi

echo "Asking for ${ocpus} OCPU / ${memory} GB"
printf '%s' "$SSH_KEY" > /tmp/instance_key.pub

response=$(oci compute instance launch \
  --availability-domain "$AD" \
  --compartment-id "$COMPARTMENT" \
  --display-name powgrove \
  --shape VM.Standard.A1.Flex \
  --shape-config "{\"ocpus\":$ocpus,\"memoryInGBs\":$memory}" \
  --image-id "$IMAGE" \
  --subnet-id "$SUBNET" \
  --assign-public-ip true \
  --ssh-authorized-keys-file /tmp/instance_key.pub \
  --wait-for-state RUNNING \
  2>&1)
rc=$?

if [ $rc -eq 0 ]; then
  ocid=$(echo "$response" | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["id"])')
  ip=$(oci compute instance list-vnics --instance-id "$ocid" \
         --query 'data[0]."public-ip"' --raw-output)
  say "## Instance created"
  say ""
  say "- **IP**: \`$ip\`"
  say "- **Shape**: ${ocpus} OCPU / ${memory} GB"
  out result created
  out ip "$ip"
  out ocid "$ocid"
  out shape "${ocpus} OCPU / ${memory} GB"
  exit 0
fi

if echo "$response" | grep -q "Out of host capacity"; then
  say "No capacity for ${ocpus} OCPU / ${memory} GB. Will try again."
  out result no-capacity
  exit 0
fi

if echo "$response" | grep -q "TooManyRequests"; then
  say "Throttled by Oracle — this run backs off and the next one tries again."
  out result throttled
  exit 0
fi

# Anything else is a real problem: a revoked key, a deleted subnet, a quota.
# Fail loudly, because a silent hunt that can never succeed is worse than none.
say "## Unexpected error"
say ""
say '```'
say "$(echo "$response" | head -20)"
say '```'
out result error
exit 1
