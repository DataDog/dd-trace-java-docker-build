
# dd-trace-java-docker-build

Docker images for continuous integration jobs at [dd-trace-java](https://github.com/datadog/dd-trace-java).

## Usage

Pre-built images are available in [GitHub Container Registry](https://github.com/DataDog/dd-trace-java-docker-build/pkgs/container/dd-trace-java-docker-build).

Image variants are available on a per JDK basis:
- The `base` variant, and its aliases `8`, `11`, `17`, contains the base Eclipse Temurin JDK 8, 11 and 17 versions,
- The `zulu8`, `zulu11`, `oracle8`, `ibm8`, `semeru8`, `semeru11`, `semeru17`, `graalvm11` and `graalvm17` variants all contain the base JDKs in addition to their specific JDK from their name,
- The `latest` variant contains the base JDKs and all the above specific JDKs.

## Development

To build all the Docker images:

```bash
./build
```

And then check the built images:

```bash
./build --test
```
