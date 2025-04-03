# Dev Spaces Image with Dotnet and Python

This is a custom Red Hat OpenShift Dev Spaces with .NET and Python libraries installed

## Build

Create a BuildConfig that builds this [Containerfile](Containerfile) in the OpenShift integrated registry:
```
oc apply -f manifests/
```

After building the image, it should be available at `image-registry.openshift-image-registry.svc:5000/openshift/devspaces-dotnet-python:latest`

