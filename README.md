Concourse-CI Images build
=========================
[![REUSE status](https://api.reuse.software/badge/github.com/gardener/concourse)](https://api.reuse.software/info/github.com/gardener/concourse)

This repository was inspired by https://github.com/robinhuiser/concourse-arm64.

Different than the original Concourse-Image-Build, none of the prebuilt/prepackaged resources
Concourse is typically delivered with are included (except for the `registry-image` resource, which
is included in order to allow for custom resources to be added). Also, there are dedicated images
for web- (provides web-ui + API + db-handling) and worker-pods (run the actual payload). There are
still some overlaps between those two images, though.

Additional resources need to be declared in pipeline-definitions.

The image-builds were tweaked such that they use "latest-and-greatest" both for base-images and
build-tools (golang version in particular). Base-images were also switched from ubuntu to debian.
In some cases, unnecessary contents were removed in order to reduce image sizes.

All images (with the notable exception of the web-image) are built for both linux/arm64 and
linux/amd64. The images have only been tested / built for being used in a k8s-deployment.
