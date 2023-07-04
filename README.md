# dotfiles

Even when keeping your MacBook configuration minimal you still end up having some dotfiles and Homebrew formulas installed. With this couple of files you'll be able to make a snapshot of the configured directories to an S3 bucket.

Creating an S3 bucket[^terraform], copying the security credentials of an IAM user with RW access to S3 buckets and launching `make` should suffice for setting a schedule of 1 snapshot per day.

The code should be pretty straightforward and you should be able to change it based on your needs.

## Commands

```bash
./sync.sh -w -f ./config.yaml # save from old Mac
./sync.sh -r -f ./config.yaml # dump on new Mac
```

## Configuration file

```yaml
s3_bucket_name: com.github.giuscri.dotfiles

paths: # explicit paths to sync
  - ~/.ssh
  - ~/.gnupg
  - ~/.vimrc
  - ~/.zshrc
  - ~/.zprofile

# `true` if apps installed using Homebrew (and their configs) must be synched
formulae: true
```

[^terraform]: A basic Terraform configuration expecting to use Terraform Cloud as the backend is provided in case you need one. You must export `TF_CLOUD_ORGANIZATION` for Terraform to work.
