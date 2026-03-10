# dd-trace-java-docker-build

This repository holds the original Docker images for continuous integration jobs in [dd-trace-java](https://github.com/datadog/dd-trace-java). The images built here are mirrored into `registry.ddbuild.io` before use in `dd-trace-java` CI. This is to ensure that all CI images are properly signed. See [DataDog/images image-mirroring](https://github.com/DataDog/images#image-mirroring) for more details.

## Usage

Pre-built images are available in the [GitHub Container Registry](https://github.com/DataDog/dd-trace-java-docker-build/pkgs/container/dd-trace-java-docker-build).

Image variants are available on a per JDK basis:
- The `base` variant and its aliases — `8`, `11`, `17`, `21`, `25`, and `tip` — contain the base Eclipse Temurin JDK 8, 11, 17, 21, 25, and tip JDK version releases.
- The `zulu8`, `zulu11`, `oracle8`, `ibm8`, `semeru8`, `semeru11`, `semeru17`, `graalvm17`, `graalvm21`, and `graalvm25` variants all contain the base JDKs in addition to the specific JDK from their name.
- The `latest` variant contains the base JDKs and all of the specific JDKs above.

Images are tagged via the [Tag new images version](https://github.com/DataDog/dd-trace-java-docker-build/actions/workflows/docker-tag.yml) workflow. This workflow tags the latest images built from the specified branch with a `ci-` prefix and triggers the [Update mirror digests for ci-* images](https://github.com/DataDog/dd-trace-java-docker-build/actions/workflows/update-mirror-digests.yml) workflow which automatically creates a PR that updates the pinned `ci-*` image digests in `DataDog/images`. It runs quarterly on `master` but can also be triggered manually as needed.

## Development

To build all the Docker images:

```bash
./build
```

And then check the built images:

```bash
./build --test
```

## Testing

Images are built per PR for ease in testing. These test images are prefixed with `N_merge-`, where N is the PR number. See the [GitHub Container Registry](https://github.com/DataDog/dd-trace-java-docker-build/pkgs/container/dd-trace-java-docker-build) for examples.

To test these images in `dd-trace-java` CI:

1. Open a PR in [DataDog/dd-trace-java-docker-build](https://github.com/DataDog/dd-trace-java-docker-build) with the changes you want to test. Let's say these changes are made in PR #123 ([example](https://github.com/DataDog/dd-trace-java-docker-build/pull/123)).
2. Run the [Create test image mirror PR](https://github.com/DataDog/dd-trace-java-docker-build/actions/workflows/create-test-mirror-pr.yml) workflow with `pr_number=123`. This automatically opens a PR in [DataDog/images](https://github.com/DataDog/images) that adds mirror entries for the `123_merge-*` test images. The PR should be automatically merged by the `dd-prapprover` bot.
3. Open a PR in [DataDog/dd-trace-java](https://github.com/DataDog/dd-trace-java) that sets `BUILDER_IMAGE_VERSION_PREFIX: "123_merge-"` in `.gitlab-ci.yml`. Here, you can check your test images with `DataDog/dd-trace-java` CI.
4. Every time you want to test changes made in PR #123, ensure the test image SHAs in `DataDog/images` are updated. This should be done by running the [Create test image mirror PR](https://github.com/DataDog/dd-trace-java-docker-build/actions/workflows/create-test-mirror-pr.yml) workflow with `pr_number=123`.
5. When the test images look good and `DataDog/dd-trace-java` CI is green, merge your `DataDog/dd-trace-java-docker-build` PR #123, close the test `DataDog/dd-trace-java` PR, and **remove the test images from the `DataDog/images` repo**.
6. Finally, run the [Tag new images version](https://github.com/DataDog/dd-trace-java-docker-build/actions/workflows/docker-tag.yml) workflow. The [Update mirror digests for ci-* images](https://github.com/DataDog/dd-trace-java-docker-build/actions/workflows/update-mirror-digests.yml) workflow will automatically open a PR in `DataDog/images`, updating the pinned `ci-*` digests.
