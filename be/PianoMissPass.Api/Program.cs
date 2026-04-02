using System.Text;
using System.Security.Claims;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using PianoMissPass.Application;
using PianoMissPass.Infrastructure;
using PianoMissPass.Infrastructure.Data;
using PianoMissPass.Api.Middleware;
using PianoMissPass.Api.Swagger;
using DotNetEnv;

var envCandidates = new[]
{
    Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", ".env"),
    Path.Combine(AppContext.BaseDirectory, "..", "..", "..", ".env")
};

var envPath = envCandidates.FirstOrDefault(File.Exists);
if (!string.IsNullOrWhiteSpace(envPath))
{
    Env.Load(envPath);
}

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddInfrastructure(builder.Configuration);
builder.Services.AddApplication();

var jwtSecret = builder.Configuration["Jwt:Secret"] ?? "CHANGE_THIS_TO_A_LONG_RANDOM_SECRET_KEY_32+";
var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "PianoMissPass";
var jwtAudience = builder.Configuration["Jwt:Audience"] ?? "PianoMissPass.Client";

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtIssuer,
            ValidAudience = jwtAudience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret)),
            RoleClaimType = ClaimTypes.Role
        };
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("AdminOnly", policy => policy.RequireRole("Admin"));
    options.AddPolicy("UserOrAdmin", policy => policy.RequireRole("User", "Admin"));
});
builder.Services.AddControllers().AddJsonOptions(options =>
{
    options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
});
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo { Title = "PianoMissPass API", Version = "v1" });

    var securityScheme = new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Description = "Enter: Bearer {your JWT token}",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        Reference = new OpenApiReference
        {
            Type = ReferenceType.SecurityScheme,
            Id = "Bearer"
        }
    };

    options.AddSecurityDefinition("Bearer", securityScheme);
    options.OperationFilter<SwaggerAuthorizeOperationFilter>();
    options.OperationFilter<SwaggerExamplesOperationFilter>();
});

var app = builder.Build();

var seedEnabled = builder.Configuration.GetValue<bool?>("SeedData:Enabled") ?? app.Environment.IsDevelopment();
if (seedEnabled)
{
    await SampleDataSeeder.SeedAsync(app.Services);
}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseMiddleware<ExceptionMiddleware>();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();

