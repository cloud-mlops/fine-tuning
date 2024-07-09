export VERSION=$1
echo ${VERSION}
gcloud builds submit . --tag us-docker.pkg.dev/gkebatchexpce3c8dcb/llm/finetune:${VERSION} --project gkebatchexpce3c8dcb
kubectl apply -n ml-team -f provisioningrequest-a2.yaml
sed -e s/VERSION/${VERSION}/g kr-fine-tune-a2.yaml | kubectl apply -n ml-team -f - 