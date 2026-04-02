using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PianoMissPass.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddOtpBruteForceLockout : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "VerificationFailedAttempts",
                table: "User",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<DateTime>(
                name: "VerificationFailedWindowStartAt",
                table: "User",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "VerificationLockedUntilAt",
                table: "User",
                type: "timestamp with time zone",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "VerificationFailedAttempts",
                table: "User");

            migrationBuilder.DropColumn(
                name: "VerificationFailedWindowStartAt",
                table: "User");

            migrationBuilder.DropColumn(
                name: "VerificationLockedUntilAt",
                table: "User");
        }
    }
}
