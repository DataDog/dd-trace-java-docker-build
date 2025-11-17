# dd-trace-java-docker-build

This library holds Docker images for continuous integration jobs at [dd-trace-java](https://github.com/datadog/dd-trace-java).

## Usage

Pre-built images are available in [GitHub Container Registry](https://github.com/DataDog/dd-trace-java-docker-build/pkgs/container/dd-trace-java-docker-build).

Image variants are available on a per JDK basis:
- The `base` variant and its aliases, `8`, `11`, `17`, `21`, `25`, and `stable`, contain the base Eclipse Temurin JDK 8, 11, 17, 21, 25, and latest stable JDK versions,
- The `zulu8`, `zulu11`, `oracle8`, `ibm8`, `semeru8`, `semeru11`, `semeru17`, `graalvm17`, `graalvm21`, and `graalvm25` variants all contain the base JDKs in addition to the specific JDK from their name,
- The `latest` variant contains the base JDKs and all the above specific JDKs.

Images are tagged via the [Tag new images version](https://github.com/DataDog/dd-trace-java-docker-build/actions/workflows/docker-tag.yml) workflow. This workflow tags the latest images built from the specified branch using the `vYY.MM` format. It runs quarterly on `master` but can also be triggered manually as needed.

## Development

To build all the Docker images:

```bash
./build
```

And then check the built images:

```bash
./build --test
```
