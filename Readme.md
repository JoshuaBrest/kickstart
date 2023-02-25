# Kickstart

Licensed under the MIT License.

## Introduction

Kickstart is a tool to quickly install apps onto a mac. It is written purely in shell script and is thus easy to use. It does however require a homebrew plugin which it does automaticly install, but that's it.

## Usage

As Kickstart is writen in pure shell, it is only one command that is require to install all the configured apps.

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/JoshuaBrest/kickstart/HEAD/kick.sh)"
```
