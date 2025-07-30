// Package fn implements a Crossplane Composition Function.
package fn

import (
	"context"

	"github.com/crossplane/function-sdk-go/errors"
	"github.com/crossplane/function-sdk-go/logging"
	fnv1 "github.com/crossplane/function-sdk-go/proto/v1"
	"github.com/crossplane/function-sdk-go/request"
	"github.com/crossplane/function-sdk-go/resource"
	"github.com/crossplane/function-sdk-go/resource/composed"
	"github.com/crossplane/function-sdk-go/response"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
)

// Function returns whatever response you ask it to.
type Function struct {
	fnv1.UnimplementedFunctionRunnerServiceServer

	log logging.Logger
}

// NewFunction creates an instance of Function.
func NewFunction(log logging.Logger) *Function {
	return &Function{log: log}
}

// RunFunction observes an XNetworks composite resource (XR). It adds a SQLInstance nop resource
// to the desired state with a name matching the XNetworks XR.
func (f *Function) RunFunction(_ context.Context, req *fnv1.RunFunctionRequest) (*fnv1.RunFunctionResponse, error) {
	f.log.Info("Running Function", "tag", req.GetMeta().GetTag())

	// Create a response to the request. This copies the desired state and
	// pipeline context from the request to the response.
	rsp := response.To(req, response.DefaultTTL)

	// Read the observed XR from the request. Most functions use the observed XR
	// to add desired managed resources.
	xr, err := request.GetObservedCompositeResource(req)
	if err != nil {
		// You can set a custom status condition on the claim. This
		// allows you to communicate with the user.
		response.ConditionFalse(rsp, "FunctionSuccess", "InternalError").
			WithMessage("Something went wrong.").
			TargetCompositeAndClaim()

		// You can emit an event regarding the claim. This allows you to
		// communicate with the user. Note that events should be used
		// sparingly and are subject to throttling
		response.Warning(rsp, errors.New("something went wrong")).
			TargetCompositeAndClaim()

		// If the function can't read the XR, the request is malformed. This
		// should never happen. The function returns a fatal result. This tells
		// Crossplane to stop running functions and return an error.
		response.Fatal(rsp, errors.Wrapf(err, "cannot get observed composite resource from %T", req))
		return rsp, nil
	}

	// Create an updated logger with useful information about the XR.
	log := f.log.WithValues(
		"xr-version", xr.Resource.GetAPIVersion(),
		"xr-kind", xr.Resource.GetKind(),
		"xr-name", xr.Resource.GetName(),
	)

	// Get the `name` from the XR metadata.
	name, err := xr.Resource.GetString("metadata.name")
	if err != nil {
		response.Fatal(rsp, errors.Wrapf(err, "cannot read metadata.name field of %s", xr.Resource.GetKind()))
		return rsp, nil
	}

	// Get all desired composed resources from the request. The function will
	// update this map of resources, then save it. This get, update, set pattern
	// ensures the function keeps any resources added by other functions.
	desired, err := request.GetDesiredComposedResources(req)
	if err != nil {
		response.Fatal(rsp, errors.Wrapf(err, "cannot get desired resources from %T", req))
		return rsp, nil
	}

	// Add a desired resource. This should ideally take advantage of Go's
	// strong typing and use imported types, instead of an Unstructured resource.
	b := &unstructured.Unstructured{
		Object: map[string]interface{}{
			"apiVersion": "example.org/v1alpha1",
			"kind":       "SQLInstance",
			"metadata": map[string]interface{}{
				"name": name,
			},
			"spec": map[string]interface{}{},
		},
	}

	// Convert the managed resource to the unstructured resource data format the SDK
	// uses to store desired composed resources.
	cd, err := composed.From(b)
	if err != nil {
		response.Fatal(rsp, errors.Wrapf(err, "cannot convert %T to %T", b, &composed.Unstructured{}))
		return rsp, nil
	}

	// Add the managed resource to the map of desired composed resources. It's
	// important that the function adds the same managed resource every time it's
	// called. It's also important that the managed resource is added with the same
	// resource.Name every time it's called. The function prefixes the name
	// with "sqlinstance-" to avoid collisions with any other composed
	// resources that might be in the desired resources map.
	desired[resource.Name("sqlinstance-"+name)] = &resource.DesiredComposed{Resource: cd}

	// Finally, save the updated desired composed resources to the response.
	if err := response.SetDesiredComposedResources(rsp, desired); err != nil {
		response.Fatal(rsp, errors.Wrapf(err, "cannot set desired composed resources in %T", rsp))
		return rsp, nil
	}

	// Log what the function did. This will only appear in the function's pod
	// logs. A function can use response.Normal and response.Warning to emit
	// Kubernetes events associated with the XR it's operating on.
	log.Info("Added desired resource(s)", "name", name, "count", len(desired))

	// You can set a custom status condition on the claim. This allows you
	// to communicate with the user.
	response.ConditionTrue(rsp, "FunctionSuccess", "Success").
		TargetCompositeAndClaim()

	return rsp, nil
}
