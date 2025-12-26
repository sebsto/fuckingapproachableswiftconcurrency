#!/bin/bash
#MISE description="Deploy the website to Cloudflare Pages"

set -e

pnpm run build
wrangler pages deploy _site --project-name=fuckingapproachableswiftconcurrency
