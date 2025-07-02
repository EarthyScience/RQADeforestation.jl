# Contributing to RQADeforestation.jl

First off, thanks for taking the time to contribute!
This file collects important information for local development of the package.

## Local setup

Install `just` into your system, following its README [installation instructions](https://github.com/casey/just?tab=readme-ov-file#installation).

Then run

```bash
just init
```

This will for instance setup pre-commit to enforce the standard Julia styling [blue](https://github.com/JuliaDiff/BlueStyle).

## Issues

We use [GitHub issue tracker](https://github.com/EarthyScience/RQADeforestation.jl/issues).
Pull Requests to the [origin main branch](https://github.com/EarthyScience/RQADeforestation.jl) are always welcome!

## Tests

Tests entrypoint is the [test directory](test).
We use [TestItemRunner](https://github.com/julia-vscode/TestItemRunner.jl) for unit tests.

## Documentation

We use [Documenter](https://documenter.juliadocs.org/stable/) to document the individual Julia functions.
See the [docs directory](docs) for further details.
In addition, we document the entire umbrella project [here](https://earthyscience.github.io/FAIRSenDD/).
