# Image Resize Function

The easiest way to resize images stored in Blob Storage (on Azure); uses [ImageSharp](https://github.com/SixLabors/ImageSharp)

## Quick Deploy to Azure

[![Deploy to Azure](http://azuredeploy.net/deploybutton.svg)](https://azuredeploy.net/)

## Configuration

Please follow these steps:

* Deploy the Function to your subscription
* Create an Azure Container Registry and a container image
* Grant contributor access in the ACR for the function identity
* Create a RG where to place the ACI
* Grant contributor access in that RG for the function identity

## Application settings

No application settings required. The following parameters to be passed on as query parameters or in a JSON body (POST):

* rg_name: the resource group name where the ACI will be created
* aci_name: the name of the ACI that will be created
* acr_name: the name of the ACR
* acr_rg_name: the RG where the ACR is located
* image_name: the name of the image

Example of a JSON body that can be used in a post:

```
{
  "rg_name": "my_aci_rg",
  "aci_name": "myaci",
  "acr_name": "myacr",
  "acr_rg_name": "myacr_rg",
  "image_name": "myimage:1.0"
}
```

## Running Locally

Visual Studio function app project is included. To run locally, create an `appsettings.json` file in the root of the function app. There is a sample included.