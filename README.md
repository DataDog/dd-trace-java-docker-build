# dd-trace-java-docker-build

This repository holds the original Docker images for continuous integration jobs in [dd-trace-java](https://github.com/datadog/dd-trace-java).

## Usage

Pre-built images are available in the [GitHub Container Registry](https://github.com/DataDog/dd-trace-java-docker-build/pkgs/container/dd-trace-java-docker-build).

Image variants are available on a per JDK basis:
- The `base` variant and its aliases — `8`, `11`, `17`, `21`, `25`, and `tip` — contain the base Eclipse Temurin JDK 8, 11, 17, 21, 25, and tip JDK version releases.
- The `zulu8`, `zulu11`, `oracle8`, `ibm8`, `semeru8`, `semeru11`, `semeru17`, `graalvm17`, `graalvm21`, and `graalvm25` variants each contain the base JDKs in addition to the specific JDK from their name.
- The `latest` variant contains the base JDKs and all of the specific JDKs above.

Images are tagged with `ci-` prefixes via the [Tag new images version](https://github.com/DataDog/dd-trace-java-docker-build/actions/workflows/docker-tag.yml) workflow, which runs quarterly on `master` and when manually triggered. On completion, it automatically triggers the [Update mirror digests for ci-* images](https://github.com/DataDog/dd-trace-java-docker-build/actions/workflows/update-mirror-digests.yml) workflow, which opens a PR in [DataDog/images](https://github.com/DataDog/images) updating the pinned `ci-*` mirror image digests. Once that PR is merged, `dd-trace-java` CI picks up the updated images from `registry.ddbuild.io`. Images are mirrored in `registry.ddbuild.io` to ensure they are signed before use in CI.

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

1. Open a PR in [DataDog/dd-trace-java-docker-build](https://github.com/DataDog/dd-trace-java-docker-build) with the changes you want to test. Let's say these changes are made in PR #N.
2. After the PR images are built/updated in the [GitHub Container Registry](https://github.com/DataDog/dd-trace-java-docker-build/pkgs/container/dd-trace-java-docker-build), run the [Create test image mirror PR](https://github.com/DataDog/dd-trace-java-docker-build/actions/workflows/create-test-mirror-pr.yml) workflow with the corresponding PR number: `N`. This automatically opens a PR in [DataDog/images](https://github.com/DataDog/images) that adds mirror entries for the `N_merge-*` test images. Merge the PR if not done automatically by the `dd-prapprover` bot.
3. Open a PR in [DataDog/dd-trace-java](https://github.com/DataDog/dd-trace-java) that sets `BUILDER_IMAGE_VERSION_PREFIX: "N_merge-"` in `.gitlab-ci.yml`. Here, you can check your test images with `DataDog/dd-trace-java` CI.
4. Every time you want to test changes made in PR #N, ensure the test image SHAs in `DataDog/images` are updated by running the [Create test image mirror PR](https://github.com/DataDog/dd-trace-java-docker-build/actions/workflows/create-test-mirror-pr.yml) workflow with `N`.
5. When the test images look good and `DataDog/dd-trace-java` CI is green, merge your `DataDog/dd-trace-java-docker-build` PR #N, close the test `DataDog/dd-trace-java` PR, and **remove the `N_merge-*` images from the `DataDog/images` repo**.
6. Finally, run the [Tag new images version](https://github.com/DataDog/dd-trace-java-docker-build/actions/workflows/docker-tag.yml) workflow. The [Update mirror digests for ci-* images](https://github.com/DataDog/dd-trace-java-docker-build/actions/workflows/update-mirror-digests.yml) workflow will automatically open a PR in `DataDog/images`, updating the pinned `ci-*` digests. `dd-trace-java` CI should automatically pick up these updated images a few minutes after the PR is merged.
