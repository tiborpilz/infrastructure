Currently, generating a terraform config as well as a rke cluster config is possible.

There is a lot of flexibility missing though.

Todo:
 * Check if cluster addons were installed correctly.
 * Check if `gitops/services` are able to be installed manually.
 * Streamline the jsonnet for the vms and the rke config.
 * Make a decision which services need to be deployed,
   find a way for those to be integrated into the jsonnet set up.
 * Simplify redundant definitions, like the verbose and inflexible ingress configs.
 
Maybe?:
 * Render all kubernetes resources - ingesting the deployment files from the server (or hard cached in the repo)
 * If possible and sane - find a way to define all necessary kubernetes resources as terraform resources,
   so that the whole cluster state can be deployed via terraform cli.


Thinks to think about:
 - Is it better to render the jsonnet in each build step (and while developing), or would it be cool
   way to promote the jsonnet to actual templates, akin to a build artifact?
 - Find an elegant solution for secrets. Git secrets is a pain in github ci, and the whole process needs to work in something
   not deployed by itself. (Contenders: cloud.drone.io and gitlab.com).
   Analog, find a way for free 'non-self-hosted' secrets management, that A. doesn't suck, and B. can be easily replaced or
   augmented by something like a self deployed Vault.
