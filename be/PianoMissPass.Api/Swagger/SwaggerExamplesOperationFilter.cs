using Microsoft.OpenApi.Any;
using Microsoft.OpenApi.Models;
using PianoMissPass.Application.DTOs;
using Swashbuckle.AspNetCore.SwaggerGen;

namespace PianoMissPass.Api.Swagger;

public class SwaggerExamplesOperationFilter : IOperationFilter
{
    public void Apply(OpenApiOperation operation, OperationFilterContext context)
    {
        var actionName = context.ApiDescription.ActionDescriptor.RouteValues.TryGetValue("action", out var value)
            ? value
            : string.Empty;
        var controllerName = context.ApiDescription.ActionDescriptor.RouteValues.TryGetValue("controller", out var controller)
            ? controller ?? string.Empty
            : string.Empty;

        if (string.Equals(actionName, "GetAll", StringComparison.OrdinalIgnoreCase))
        {
            ApplySortQueryMetadata(operation, controllerName);
        }

        switch (actionName)
        {
            case "Register":
                SetRequestExample(operation, new OpenApiObject
                {
                    ["userName"] = new OpenApiString("admin"),
                    ["email"] = new OpenApiString("admin@example.com"),
                    ["password"] = new OpenApiString("Password123!"),
                    ["avatarUrl"] = new OpenApiString("https://cdn.example.com/avatar.png"),
                    ["role"] = new OpenApiString("User")
                });
                SetResponseExample(operation, "200", new OpenApiObject
                {
                    ["accessToken"] = new OpenApiString("eyJhbGciOi..."),
                    ["refreshToken"] = new OpenApiString("refresh_token_value"),
                    ["expiresAtUtc"] = new OpenApiString("2026-04-02T12:00:00Z")
                });
                break;
            case "Login":
                SetRequestExample(operation, new OpenApiObject
                {
                    ["email"] = new OpenApiString("admin@example.com"),
                    ["password"] = new OpenApiString("Password123!")
                });
                SetResponseExample(operation, "200", new OpenApiObject
                {
                    ["accessToken"] = new OpenApiString("eyJhbGciOi..."),
                    ["refreshToken"] = new OpenApiString("refresh_token_value"),
                    ["expiresAtUtc"] = new OpenApiString("2026-04-02T12:00:00Z")
                });
                break;
            case "Refresh":
            case "Revoke":
                SetRequestExample(operation, new OpenApiObject
                {
                    ["refreshToken"] = new OpenApiString("refresh_token_value")
                });
                break;
            case "UpdateRole":
                SetRequestExample(operation, new OpenApiObject
                {
                    ["role"] = new OpenApiString("Admin")
                });
                SetResponseExample(operation, "200", new OpenApiObject
                {
                    ["id"] = new OpenApiInteger(1),
                    ["userName"] = new OpenApiString("admin"),
                    ["email"] = new OpenApiString("admin@example.com"),
                    ["avatarUrl"] = new OpenApiString("https://cdn.example.com/avatar.png"),
                    ["role"] = new OpenApiString("Admin"),
                    ["createdAt"] = new OpenApiString("2026-04-02T10:00:00Z"),
                    ["updatedAt"] = new OpenApiString("2026-04-02T10:30:00Z")
                });
                break;
        }
    }

    private static void ApplySortQueryMetadata(OpenApiOperation operation, string controllerName)
    {
        string[] allowedSortKeys;
        string description;

        switch (controllerName)
        {
            case "Songs":
                allowedSortKeys = ["title_asc", "title_desc", "updated_asc", "updated_desc", "play_asc", "play_desc"];
                description = "Sort key. Allowed values: title_asc, title_desc, updated_asc, updated_desc, play_asc, play_desc.";
                break;
            case "Sheets":
                allowedSortKeys = ["title_asc", "title_desc", "updated_asc", "updated_desc", "like_asc", "like_desc"];
                description = "Sort key. Allowed values: title_asc, title_desc, updated_asc, updated_desc, like_asc, like_desc.";
                break;
            case "Users":
            case "Playlists":
                allowedSortKeys = ["title_asc", "title_desc", "updated_asc", "updated_desc"];
                description = "Sort key. Allowed values: title_asc, title_desc, updated_asc, updated_desc.";
                break;
            default:
                return;
        }

        var sortParameter = operation.Parameters.FirstOrDefault(x =>
            string.Equals(x.Name, "sort", StringComparison.OrdinalIgnoreCase));

        if (sortParameter is null)
        {
            return;
        }

        sortParameter.Description = description;
        sortParameter.Schema ??= new OpenApiSchema { Type = "string" };
        sortParameter.Schema.Enum = allowedSortKeys
            .Select(x => (IOpenApiAny)new OpenApiString(x))
            .ToList();
        sortParameter.Example = new OpenApiString("updated_desc");
    }

    private static void SetRequestExample(OpenApiOperation operation, OpenApiObject example)
    {
        operation.RequestBody ??= new OpenApiRequestBody();
        operation.RequestBody.Content.TryAdd("application/json", new OpenApiMediaType());
        operation.RequestBody.Content["application/json"].Example = example;
    }

    private static void SetResponseExample(OpenApiOperation operation, string responseCode, OpenApiObject example)
    {
        if (!operation.Responses.TryGetValue(responseCode, out var response))
        {
            response = new OpenApiResponse { Description = "Example" };
            operation.Responses[responseCode] = response;
        }

        response.Content.TryAdd("application/json", new OpenApiMediaType());
        response.Content["application/json"].Example = example;
    }
}
