# Oracle capacity hunt

Oracle Cloud's Always Free ARM shape (`VM.Standard.A1.Flex`) is permanently
oversubscribed in some regions — every launch returns *Out of host capacity*.
Capacity does appear, for seconds at a time, at unpredictable hours, usually
when somebody else terminates an instance.

This repository is a scheduled GitHub Actions workflow that keeps asking, so a
laptop does not have to stay awake doing it. When a launch succeeds it opens an
issue with the instance's IP address and switches itself off.

It is public because GitHub bills Actions minutes on private repositories and a
round-the-clock hunt would exhaust a month's quota in days. It contains no
application code. The Oracle credentials are repository secrets, unreadable by
forks, and the workflow never runs on `pull_request`.

## Secrets it needs

| Secret | What it is |
|---|---|
| `OCI_CLI_USER` | user OCID |
| `OCI_CLI_TENANCY` | tenancy OCID |
| `OCI_CLI_FINGERPRINT` | API key fingerprint |
| `OCI_CLI_KEY_CONTENT` | the API private key, PEM, no passphrase |
| `OCI_CLI_REGION` | e.g. `ap-hyderabad-1` |
| `OCI_COMPARTMENT` | compartment to launch in |
| `OCI_SUBNET` | a **public** subnet |
| `OCI_IMAGE` | image OCID (Ubuntu 24.04, `aarch64`) |
| `OCI_AD` | availability domain |
| `INSTANCE_SSH_KEY` | SSH **public** key to authorize on the instance |

## When it succeeds

Delete the API key in the Oracle console (**User settings → Tokens and keys**)
and this repository. The key exists only to win a race that is now over.

GitHub also disables scheduled workflows in repositories with no activity for
60 days, so a long hunt needs an occasional commit — or a re-enable.
