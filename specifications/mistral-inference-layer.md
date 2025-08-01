# Refactor Project & Change Some Services


You need to make a number of changes to this project, ensuring that we comprehensively update all relevant files.   Here are the key changes we need to make:
- Let's add the ability to have multiple different inference engines that we can chose between.   We'll keep ollama but add mistral.rs.
- update the readme accordingly
- generate a comprehensive new specification that can be used to have swissarmyhammer conduct the actual local setup of the environment. (but don't run it, just make the spec)

## Adding Mistral.rs As Inference Layer Option

- Will need its own docker image and we'll need a separate docker compose. 
- go and thoroughly review the mistral.rs docs before you get started on this part of the project
  - https://github.com/EricLBuehler/mistral.rs?tab=readme-ov-file
  - https://ericlbuehler.github.io/mistral.rs/mistralrs/
- If/where we need to make a choice between python and rust, we will prefer rust.
- configure the same monitoring setup for mistral rs as the one we have for ollama

## Switching between inference layers
Given that mistral and ollama require different model formats, we will treat these as separate stacks, each with its own docker compose and other scripts/automation.  