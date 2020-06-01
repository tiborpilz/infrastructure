main.tf.json: terraform.jsonnet
	jsonnet terraform.jsonnet -o main.tf.json

cluster.yml: rke.jsonnet
	jsonnet rke.jsonnet -o cluster.yml

all: main.tf.json cluster.yml

clean:
	rm main.tf.json cluster.yml
