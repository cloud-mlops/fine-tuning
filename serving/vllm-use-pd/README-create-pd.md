# Create a pvc for use with inferencing deployment

## Bake the models into a diskimage

Follow the README in the `download-model` to bake a disk image.

## Create disk from the disk image

Use the following command, 

```bash
gcloud compute disks create _DISK_NAME_ \
  --type pd-ssd \
  --size 1024GiB \
  --image _DISK_IMAGE_NAME_ \
  --zone us-east4-c
```

Then get the disk handler

```bash
gcloud compute disks describe _DISK_NAME_ --zone us-east4-c
```

## Create the pv and pvc

Modify the `example-pd-pv.yaml`, replace the disk handler with the handler you get in the previous step.


