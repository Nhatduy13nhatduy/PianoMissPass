using System.ComponentModel.DataAnnotations;
using PianoMissPass.Domain.Entities;

namespace PianoMissPass.Application.DTOs;

public class UpdateUserRoleRequestDto
{
    [Required]
    public UserRole Role { get; set; }
}
