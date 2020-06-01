main.tf.json: main.jsonnet

cluster.yml main.tf.json: main.jsonnet
	jsonnet -m . main.jsonnet
