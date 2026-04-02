using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PianoMissPass.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddDataAssetPublicIdForCloudDelete : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "PublicId",
                table: "DataAsset",
                type: "character varying(255)",
                maxLength: 255,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "PublicId",
                table: "DataAsset");
        }
    }
}
